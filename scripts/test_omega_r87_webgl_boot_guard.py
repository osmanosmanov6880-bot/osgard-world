#!/usr/bin/env python3
"""Source-only anti-bypass checks. Fake screenshots are NEVER success evidence."""
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
SPEC=(ROOT/"scripts/omega-portrait-preview.spec.mjs").read_text()
RUNNER=(ROOT/"scripts/omega-four-viewport-real-ci.sh").read_text()
R37=(ROOT/".github/workflows/omega-r37-facade-material-qa.yml").read_text()
PORTRAIT=(ROOT/".github/workflows/omega-portrait-preview-qa.yml").read_text()
R52=(ROOT/".github/workflows/omega-r52-joined-gameplay-qa.yml").read_text()
R48=(ROOT/".github/workflows/omega-r48-frame-pacing-qa.yml").read_text()

def verify(spec=SPEC, runner=RUNNER, r37=R37, portrait=PORTRAIT, r52=R52, r48=R48):
    assert "await page.waitForFunction(()=>document.querySelector('#status')===null" in spec
    assert "expect(view.webgl2).toBe(true)" in spec
    assert "expect(view.contextLost).toBe(false)" in spec
    assert "worldEvidence=realGameFrameEvidence(png)" in spec
    assert "if(worldEvidence.realWorldEdges)break" in spec
    assert "expect(worldEvidence.upperEdgeLumaStd" in spec
    assert "expect(worldEvidence.lowerEdgeLumaStd" in spec
    assert "expect(failures).toEqual([])" in spec
    assert "info.project.name==='desktop-1366x768'?14000:700" in spec
    assert "for(let attempt=1;attempt<=5;attempt++)" in spec
    assert "if(attempt<5)await page.waitForTimeout(2000)" in spec
    assert "for viewport in desktop-1366x768 portrait-390x844 small-phone-320x568 landscape-phone-844x390; do" in runner
    assert 'test "$tested" -eq 4' in runner
    assert "--retries=0" in runner
    assert "OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1" in runner
    assert "xvfb-run -a" in runner
    assert "bash scripts/omega-four-viewport-real-ci.sh" in r37
    assert "sudo apt-get install -y xvfb libgl1-mesa-dri" in r37
    assert "bash scripts/omega-four-viewport-real-ci.sh" in portrait
    assert "actions/upload-artifact@v4" in r37
    assert 'sudo apt-get install -y xvfb libgl1-mesa-dri' in r52
    assert 'OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1' in r52
    assert "xvfb-run -a" in r52
    assert '--retries=0' in r52
    assert 'python3 scripts/test_omega_r87_webgl_boot_guard.py' in r52
    assert 'VIEWPORT: ${{ matrix.viewport }}' in r52
    assert 'sudo apt-get install -y xvfb libgl1-mesa-dri' in r48
    assert 'OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1' in r48
    assert 'xvfb-run -a' in r48
    assert '--retries=0' in r48
    assert 'python3 scripts/test_omega_r87_webgl_boot_guard.py' in r48
    assert 'VIEWPORT: ${{ matrix.viewport }}' in r48

class WebGLGuardTests(unittest.TestCase):
    def test_originals(self): verify()
    def test_no_world_diversity(self):
        with self.assertRaises(AssertionError):
            verify(spec=SPEC.replace("if(worldEvidence.realWorldEdges)break","if(true)break"))
    def test_disabled_status(self):
        with self.assertRaises(AssertionError):
            verify(spec=SPEC.replace("await page.waitForFunction(()=>document.querySelector('#status')===null","await page.waitForTimeout"))
    def test_replaced_real_pixels(self):
        with self.assertRaises(AssertionError):
            verify(spec=SPEC.replace("worldEvidence=realGameFrameEvidence(png)","worldEvidence={realWorldEdges:true}"))
    def test_missing_view(self):
        with self.assertRaises(AssertionError):
            verify(runner=RUNNER.replace("small-phone-320x568 ",""))
    def test_retry_prohibited(self):
        with self.assertRaises(AssertionError):
            verify(runner=RUNNER.replace("--retries=0","--retries=2"))
    def test_mesa_required(self):
        with self.assertRaises(AssertionError):
            verify(runner=RUNNER.replace("OMEGA_CI_GL_BACKEND=mesa","OMEGA_CI_GL_BACKEND=stub"))
    def test_r52_mesa_cannot_be_stubbed(self):
        with self.assertRaises(AssertionError):
            verify(r52=R52.replace('OMEGA_CI_GL_BACKEND=mesa','OMEGA_CI_GL_BACKEND=stub'))
    def test_r52_cannot_retry_flaky_desktop(self):
        with self.assertRaises(AssertionError):
            verify(r52=R52.replace('--retries=0','--retries=1'))
    def test_r48_mesa_cannot_be_stubbed(self):
        with self.assertRaises(AssertionError):
            verify(r48=R48.replace('OMEGA_CI_GL_BACKEND=mesa','OMEGA_CI_GL_BACKEND=stub'))
    def test_r48_cannot_retry_flaky_desktop(self):
        with self.assertRaises(AssertionError):
            verify(r48=R48.replace('--retries=0','--retries=1'))
    def test_browser_isolation_required(self):
        with self.assertRaises(AssertionError):
            verify(r37=R37.replace("bash scripts/omega-four-viewport-real-ci.sh","npx playwright test"))

if __name__=="__main__":
    unittest.main(verbosity=2)
