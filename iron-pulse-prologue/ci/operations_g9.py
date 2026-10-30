#!/usr/bin/env python3
"""G9: offline incident-drill audit ledger and operational readiness.

Hash chaining is tamper-evident ONLY against an externally pinned trusted head.
No claim of real hosting, monitoring, SLO, signed events, or production incidents.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
import release_vault_g5 as vault

SCHEMA = "IRON_PULSE_G9_OPERATIONS_V1"
EVENT_SCHEMA = "IRON_PULSE_G9_INCIDENT_EVENT_V1"
ZERO = "0"*64
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
INCIDENT = re.compile(r"DRILL-[0-9]{4,6}\Z")
CODE = re.compile(r"[A-Z][A-Z0-9_]{2,39}\Z")
STEPS = ("OPEN", "TRIAGE", "MITIGATE", "RECOVER", "CLOSE")
NEXT = {None:"OPEN", "OPEN":"TRIAGE", "TRIAGE":"MITIGATE",
        "MITIGATE":"RECOVER", "RECOVER":"CLOSE"}
CHECKS = ("support_intake_tested", "triage_runbook_reviewed",
          "oncall_backup_assigned_privately", "offline_rollback_rehearsed",
          "offline_restore_rehearsed", "data_retention_reviewed",
          "ru_en_support_prepared", "incident_comms_templates_reviewed",
          "abuse_response_prepared", "day_30_60_90_reviews_scheduled")
PACKET_KEYS = {"schema","source_sha","bundle_sha256","privacy","manual_claims_only",
               "production_approved","checks","independent_review_requested"}
EVENT_KEYS = {"schema","seq","source_sha","bundle_sha256","incident","action",
              "note_code","previous_hash","hash","scope"}

class OpsError(ValueError):
    pass

def require(value, message):
    if not value:
        raise OpsError(message)

def unique(pairs):
    out = {}
    for key, value in pairs:
        require(key not in out, "duplicate JSON property")
        out[key] = value
    return out

def canonical(data):
    return (json.dumps(data,sort_keys=True,ensure_ascii=False,
                       separators=(",",":"))+"\n").encode("utf-8")

def sha(data):
    return hashlib.sha256(data).hexdigest()

def ensure_source(source,bundle):
    require(type(source) is str and HEX40.fullmatch(source)
            and type(bundle) is str and HEX64.fullmatch(bundle),
            "external full source SHA and release bundle SHA-256 required")

def read_json(path, size=32768):
    require(path.is_file() and not path.is_symlink(),
            "missing or symlinked operations JSON")
    require(path.stat().st_size <= size,"operations JSON too large")
    try:
        data = json.loads(path.read_text("utf-8"), object_pairs_hook=unique,
            parse_constant=lambda _: (_ for _ in ()).throw(OpsError("nonfinite JSON")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise OpsError("malformed operations JSON") from exc
    require(type(data) is dict,"expected operations JSON object")
    return data

def verify_events(root,source,bundle):
    path = root/"incidents.jsonl"
    require(path.is_file() and not path.is_symlink(),"missing or symlinked incident ledger")
    require(path.stat().st_size <= 1024*1024,"incident ledger too large")
    records = path.read_bytes().splitlines(keepends=True)
    require(len(records) <= 1024,"too many incident events")
    states = {}
    last = ZERO
    completed = set()
    for seq, raw in enumerate(records,1):
        require(raw.endswith(b"\n"),"incomplete or partially written event")
        try:
            event = json.loads(raw.decode("utf-8"), object_pairs_hook=unique,
                parse_constant=lambda _: (_ for _ in ()).throw(OpsError("nonfinite event")))
        except (UnicodeError,json.JSONDecodeError) as exc:
            raise OpsError("malformed incident event") from exc
        require(type(event) is dict and set(event) == EVENT_KEYS,
                "incident event requires exact privacy-safe schema")
        require(event["schema"]==EVENT_SCHEMA and
                type(event["seq"]) is int and event["seq"]==seq and
                event["source_sha"]==source and event["bundle_sha256"]==bundle and
                event["scope"]=="offline_drill",
                "sequence/source/scope mismatch")
        inc, action, note = event["incident"], event["action"], event["note_code"]
        require(type(inc) is str and INCIDENT.fullmatch(inc),
                "invalid incident id; no private identifiers")
        require(action in STEPS and type(note) is str and CODE.fullmatch(note),
                "invalid incident action/note code")
        require(event["previous_hash"]==last and
                type(event["hash"]) is str and HEX64.fullmatch(event["hash"]),
                "incident chain link broken")
        payload = {k:v for k,v in event.items() if k!="hash"}
        require(sha(canonical(payload))==event["hash"],
                "incident event digest mismatch")
        current = states.get(inc)
        require(current != "CLOSE" and NEXT.get(current)==action,
                "incident action out of order: "+inc+" / "+action)
        states[inc]=action
        if action=="CLOSE":
            completed.add(inc)
        last=event["hash"]
    return {"event_count":len(records),"incident_count":len(states),
            "completed_offline_drills":len(completed),
            "open_incidents":sorted(i for i,v in states.items() if v!="CLOSE"),
            "head_sha256":last,"scope":"offline_drill",
            "externally_authenticated":False}

def check_packet(packet,source,bundle):
    require(type(packet) is dict and set(packet)==PACKET_KEYS,
            "invalid operational packet fields")
    require(packet["schema"]==SCHEMA and packet["source_sha"]==source
            and packet["bundle_sha256"]==bundle and packet["privacy"]=="role_flags_only"
            and packet["manual_claims_only"] is True
            and packet["production_approved"] is False
            and packet["independent_review_requested"] is True,
            "invalid operations trust boundary")
    checks=packet["checks"]
    require(type(checks) is dict and set(checks)==set(CHECKS)
            and all(checks[c] is True for c in CHECKS),
            "operational drills, support and review checks incomplete")

def assess(archive,source,bundle,root,external_head):
    ensure_source(source,bundle)
    require(root.is_dir() and not root.is_symlink(),"operations folder missing")
    info=vault.verify_archive(archive,source,bundle)
    require(info.get("verified") is True and info.get("source_sha")==source,
            "unverified exact-source Godot release")
    result={"schema":SCHEMA,"source_sha":source,"bundle_sha256":bundle,
            "status":"RELEASE_HOLD","production_approved":False,
            "commercial_release_allowed":False,"deployment_performed":False,
            "real_production_incidents_observed":False,"offline_drill_only":True,
            "independent_operator_authenticated":False,"errors":[],
            "interpretation":"Offline incident simulation and manually claimed support checks"}
    if not (root/"ops.json").exists() or not (root/"incidents.jsonl").exists():
        result["errors"]=["No private ops evidence or incident drill"]
        return result
    try:
        check_packet(read_json(root/"ops.json"),source,bundle)
        records=verify_events(root,source,bundle)
        result.update(records)
        require(records["completed_offline_drills"]>=1
                and not records["open_incidents"],
                "incomplete offline restore incident drill")
        require(type(external_head) is str and HEX64.fullmatch(external_head)
                and external_head==records["head_sha256"],
                "independently pinned final ledger head is missing/mismatched")
        result["status"]="READY_FOR_INDEPENDENT_REVIEW"
    except (OpsError,OSError,KeyError,TypeError) as exc:
        result["errors"].append(str(exc)[:250])
    return result

def init(archive,source,bundle,root):
    ensure_source(source,bundle)
    checked=vault.verify_archive(archive,source,bundle)
    require(checked.get("verified") is True and checked.get("source_sha")==source,
            "unverified release")
    require(not root.is_symlink(),"symlinked operations folder")
    root.mkdir(parents=True,exist_ok=True)
    packet=root/"ops.json"
    ledger=root/"incidents.jsonl"
    require(not packet.exists() and not packet.is_symlink()
            and not ledger.exists() and not ledger.is_symlink(),
            "refusing to overwrite operations evidence")
    data={"schema":SCHEMA,"source_sha":source,"bundle_sha256":bundle,
          "privacy":"role_flags_only","manual_claims_only":True,
          "production_approved":False,
          "checks":{check:False for check in CHECKS},
          "independent_review_requested":False}
    with packet.open("x",encoding="utf-8") as f:
        f.write(json.dumps(data,indent=2,sort_keys=True)+"\n")
    with ledger.open("x",encoding="utf-8") as f:
        f.flush()
        os.fsync(f.fileno())
    return packet

def append(root,source,bundle,incident,action,note,expected_head):
    ensure_source(source,bundle)
    require(root.is_dir() and not root.is_symlink(),"missing operations root")
    require(type(incident) is str and INCIDENT.fullmatch(incident),"unsafe incident code")
    require(action in STEPS,"invalid incident action")
    require(type(note) is str and CODE.fullmatch(note),"unsafe/private note")
    require(type(expected_head) is str and
            (expected_head=="none" or HEX64.fullmatch(expected_head)),
            "must supply known pinned previous head or none")
    lock=root/".incidents.write.lock"
    require(not lock.is_symlink(),"unsafe lock")
    with lock.open("x",encoding="utf-8") as hold:
        hold.write("exclusive offline append\n")
        hold.flush()
        try:
            data=verify_events(root,source,bundle)
            current=data["head_sha256"]
            require(current == (ZERO if expected_head=="none" else expected_head),
                    "CAS mismatch: another event was appended")
            states={}
            for raw in (root/"incidents.jsonl").read_bytes().splitlines():
                event=json.loads(raw)
                states[event["incident"]]=event["action"]
            require(states.get(incident)!="CLOSE" and
                    NEXT.get(states.get(incident))==action,
                    "invalid incident state transition")
            event={"schema":EVENT_SCHEMA,"seq":data["event_count"]+1,
                   "source_sha":source,"bundle_sha256":bundle,
                   "incident":incident,"action":action,"note_code":note,
                   "previous_hash":current,"scope":"offline_drill"}
            event["hash"]=sha(canonical(event))
            path=root/"incidents.jsonl"
            require(not path.is_symlink(),"symlinked incident journal")
            next_path=root/"incidents.jsonl.next"
            require(not next_path.exists() and not next_path.is_symlink(),
                    "unresolved or unsafe journal update")
            try:
                with next_path.open("x",encoding="utf-8") as f:
                    f.write(path.read_text("utf-8"))
                    f.write(canonical(event).decode("utf-8"))
                    f.flush()
                    os.fsync(f.fileno())
                os.replace(next_path,path)
            finally:
                if next_path.exists() and not next_path.is_symlink():
                    next_path.unlink()
            return event["hash"]
        finally:
            if lock.exists() and not lock.is_symlink():
                lock.unlink()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--archive",type=Path,required=True)
    p.add_argument("--source-sha",required=True)
    p.add_argument("--bundle-sha256",required=True)
    p.add_argument("--ops-dir",type=Path,required=True)
    p.add_argument("--output",type=Path)
    p.add_argument("--init",action="store_true")
    p.add_argument("--append",choices=STEPS)
    p.add_argument("--incident")
    p.add_argument("--note-code",default="DRILL_STEP")
    p.add_argument("--expected-head")
    p.add_argument("--expect-hold",action="store_true")
    a=p.parse_args()
    try:
        if a.init:
            require(not a.append and not a.output and not a.expect_hold,"init cannot approve")
            print(init(a.archive,a.source_sha,a.bundle_sha256,a.ops_dir))
            return 0
        if a.append:
            require(not a.output and not a.expect_hold,
                    "append is not a release authorization")
            release=vault.verify_archive(a.archive,a.source_sha,a.bundle_sha256)
            require(release.get("verified") is True,"not a verified release")
            print("OFFLINE DRILL HEAD:",append(a.ops_dir,a.source_sha,
                    a.bundle_sha256,a.incident,a.append,a.note_code,a.expected_head))
            return 0
        result=assess(a.archive,a.source_sha,a.bundle_sha256,a.ops_dir,
                      a.expected_head)
        payload=json.dumps(result,indent=2,sort_keys=True)+"\n"
        if a.output:
            require(not a.output.is_symlink(),"symlinked result output")
            a.output.parent.mkdir(parents=True,exist_ok=True)
            a.output.write_text(payload,encoding="utf-8")
        print(payload,end="")
        if a.expect_hold:
            return 0 if result["status"]=="RELEASE_HOLD" else 3
        return 0 if result["status"]=="READY_FOR_INDEPENDENT_REVIEW" else 2
    except (OpsError,vault.VaultError,OSError,TypeError) as error:
        print("G9 FAIL CLOSED:",error,file=sys.stderr)
        return 4

if __name__=="__main__":
    sys.exit(main())
