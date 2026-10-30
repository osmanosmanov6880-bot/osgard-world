#!/usr/bin/env python3
"""G8: read-only GLOBAL LAUNCH PRE-FLIGHT, never a deployment or GO authority.

Rechecks the real G5 archive, re-evaluates G6/G7/G9 private evidence, then
requires manually documented international legal/security/distribution gates.
It cannot independently authenticate human claims or authorize production.
"""
from __future__ import annotations
import argparse
import json
import re
import sys
from pathlib import Path
import release_vault_g5 as vault
import device_acceptance_g6 as g6
import human_playtest_g7 as g7
import operations_g9 as g9

SCHEMA = "IRON_PULSE_G8_GLOBAL_LAUNCH_PRECHECK_V1"
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
CATEGORIES = {
    "rights_and_legal": (
        "authored_assets_and_licenses_reviewed",
        "music_voice_and_sound_rights_reviewed",
        "trademark_name_rights_reviewed",
        "third_party_notices_complete",
        "regions_age_ratings_reviewed",
        "terms_refunds_and_consumer_law_reviewed",
    ),
    "security_and_privacy": (
        "privacy_ru_en_reviewed",
        "minimal_telemetry_and_retention_reviewed",
        "dependency_security_reviewed",
        "vulnerability_triage_completed",
        "safe_archive_supply_chain_reviewed",
        "no_high_severity_unresolved_findings",
    ),
    "platform_accessibility": (
        "real_windows_and_mobile_manual_reviewed",
        "real_safari_playthrough_reviewed",
        "screen_reader_and_visual_access_reviewed",
        "motion_audio_and_control_access_reviewed",
        "independent_art_audio_quality_reviewed",
    ),
    "distribution_and_recovery": (
        "windows_binary_signing_verified",
        "trusted_download_hash_receipt_published",
        "domain_tls_and_http_headers_reviewed",
        "hosting_staging_rehearsal_complete",
        "real_host_rollback_rehearsal_complete",
        "backup_restore_drill_completed",
        "support_and_incident_channels_verified",
    ),
    "authorization": (
        "independent_legal_security_reviewer_requested",
        "independent_hardware_witness_requested",
        "independent_human_playtest_auditor_requested",
        "responsible_release_owner_assigned_privately",
    ),
}
PACKET_FIELDS = {"schema","source_sha","bundle_sha256","production_approved",
                 "release_go_granted","manual_claims_only","privacy",
                 "evidence_review_requested","checks"}

class LaunchError(ValueError):
    pass

def require(ok, reason):
    if not ok:
        raise LaunchError(reason)

def unique(pairs):
    d={}
    for k,v in pairs:
        require(k not in d,"duplicate checklist JSON key")
        d[k]=v
    return d

def read_checklist(path):
    require(path.is_file() and not path.is_symlink(),"missing or symlinked G8 checklist")
    require(path.stat().st_size <= 32000,"oversized G8 checklist")
    try:
        packet=json.loads(path.read_text("utf-8"),object_pairs_hook=unique,
            parse_constant=lambda _: (_ for _ in ()).throw(LaunchError("nonfinite JSON")))
    except (UnicodeError,json.JSONDecodeError) as e:
        raise LaunchError("invalid G8 checklist JSON") from e
    require(type(packet) is dict and set(packet)==PACKET_FIELDS,
            "checklist has missing/unknown fields or privacy leak")
    return packet

def validate(packet,source,bundle):
    require(packet["schema"]==SCHEMA and packet["source_sha"]==source
            and packet["bundle_sha256"]==bundle
            and packet["production_approved"] is False
            and packet["release_go_granted"] is False
            and packet["manual_claims_only"] is True
            and packet["privacy"]=="roles_and_boolean_claims_only"
            and packet["evidence_review_requested"] is True,
            "invalid source/privacy or forged GO")
    checks=packet["checks"]
    require(type(checks) is dict and set(checks)==set(CATEGORIES),
            "missing one international release gate group")
    for category,values in CATEGORIES.items():
        items=checks[category]
        require(type(items) is dict and set(items)==set(values)
                and all(items[key] is True for key in values),
                "incomplete approval checklist: "+category)

def result_base(source,bundle):
    return {"schema":SCHEMA,"source_sha":source,"bundle_sha256":bundle,
            "status":"RELEASE_HOLD","production_approved":False,
            "commercial_release_allowed":False,"deployment_performed":False,
            "human_launch_authorization_authenticated":False,
            "real_host_rollout_verified_by_code":False,
            "source_bound_archive_verified":False,"errors":[],
            "upstream_statuses":{},
            "interpretation":"Pre-launch audit only; never a production authorization"}

def assess(archive,source,bundle,root,ops_head=""):
    require(type(source) is str and HEX40.fullmatch(source)
            and type(bundle) is str and HEX64.fullmatch(bundle),
            "trusted source and archive digest required")
    require(root.is_dir() and not root.is_symlink(),"private gate root missing")
    archive_proof=vault.verify_archive(archive,source,bundle)
    require(archive_proof.get("verified") is True
            and archive_proof.get("source_sha")==source,
            "unverified source-bound Godot archive")
    out=result_base(source,bundle)
    out["source_bound_archive_verified"]=True
    for key,folder in (("G6","g6"),("G7","g7"),("G9","g9")):
        if not (root/folder).is_dir() or (root/folder).is_symlink():
            out["errors"].append(key+" evidence folder missing")
            out["upstream_statuses"][key]="RELEASE_HOLD"
            continue
        try:
            if key=="G6":
                child=g6.evaluate(archive,source,bundle,root/folder)
            elif key=="G7":
                child=g7.assess(archive,source,bundle,root/folder)
            else:
                child=g9.assess(archive,source,bundle,root/folder,ops_head)
            out["upstream_statuses"][key]=child.get("status")
            if child.get("status")!="READY_FOR_INDEPENDENT_REVIEW":
                out["errors"].append(key+" independent review evidence incomplete")
            require(child.get("production_approved") is False
                    and child.get("commercial_release_allowed") is False,
                    "upstream subgate falsely grants production")
        except (LaunchError,g6.GateError,g7.TrialError,g9.OpsError,vault.VaultError,
                OSError,ValueError,KeyError,TypeError) as ex:
            out["upstream_statuses"][key]="RELEASE_HOLD"
            out["errors"].append(key+" invalid evidence: "+str(ex)[:100])
    checklist=root/"g8"/"checklist.json"
    try:
        packet=read_checklist(checklist)
        validate(packet,source,bundle)
    except (LaunchError,OSError,TypeError,KeyError) as ex:
        out["errors"].append("G8 manual checklist incomplete: "+str(ex)[:120])
    if not out["errors"]:
        out["status"]="READY_FOR_INDEPENDENT_LAUNCH_AUDIT"
        out["interpretation"]=("Structurally consistent operator claims only; "
                               "independently authenticated human GO and real-host "
                               "deployment still missing")
    return out

def init(archive,source,bundle,root):
    proof=vault.verify_archive(archive,source,bundle)
    require(proof.get("verified") is True and proof.get("source_sha")==source,
            "unverified release archive")
    require(not root.is_symlink(),"symlinked gate directory")
    path=root/"g8"/"checklist.json"
    require(not path.exists() and not path.is_symlink(),
            "refuse to overwrite legal/security evidence")
    path.parent.mkdir(parents=True,exist_ok=True)
    packet={"schema":SCHEMA,"source_sha":source,"bundle_sha256":bundle,
            "production_approved":False,"release_go_granted":False,
            "manual_claims_only":True,"privacy":"roles_and_boolean_claims_only",
            "evidence_review_requested":False,
            "checks":{k:{item:False for item in names}
                      for k,names in CATEGORIES.items()}}
    with path.open("x",encoding="utf-8") as f:
        f.write(json.dumps(packet,indent=2,sort_keys=True)+"\n")
    return path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--archive",required=True,type=Path)
    p.add_argument("--source-sha",required=True)
    p.add_argument("--bundle-sha256",required=True)
    p.add_argument("--evidence-root",required=True,type=Path)
    p.add_argument("--ops-head",default="")
    p.add_argument("--output",type=Path)
    p.add_argument("--init",action="store_true")
    p.add_argument("--expect-hold",action="store_true")
    args=p.parse_args()
    try:
        if args.init:
            require(not args.output and not args.expect_hold,"init cannot approve")
            print(init(args.archive,args.source_sha,args.bundle_sha256,
                       args.evidence_root))
            return 0
        out=assess(args.archive,args.source_sha,args.bundle_sha256,
                   args.evidence_root,args.ops_head)
        payload=json.dumps(out,sort_keys=True,indent=2)+"\n"
        if args.output:
            require(not args.output.is_symlink(),"symlinked G8 result")
            args.output.parent.mkdir(parents=True,exist_ok=True)
            args.output.write_text(payload,encoding="utf-8")
        print(payload,end="")
        if args.expect_hold:
            return 0 if out["status"]=="RELEASE_HOLD" else 3
        return 0 if out["status"]=="READY_FOR_INDEPENDENT_LAUNCH_AUDIT" else 2
    except (LaunchError,vault.VaultError,OSError,TypeError,ValueError) as e:
        print("G8 FAIL CLOSED:",e,file=sys.stderr)
        return 4

if __name__=="__main__":
    sys.exit(main())
