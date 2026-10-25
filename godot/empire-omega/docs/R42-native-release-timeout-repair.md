# R42 production release incident and exact native test budget

Protected Godot Web export #40172018435 failed after every gameplay regression
except `v59_r40_force_motor_calibration.gd` passed. That R40 six-candidate
real Godot RigidBody3D physical sweep needs ~40s when run as a dedicated native
CI job, but the legacy sweep runner imposed the same **15 second** timeout on
all test files. The test was killed (exit 124), so no R42 binary was built or
published. This is a release-gate configuration defect, not evidence that
the R40 physics itself failed.

The repair raises only the actual calibration test's upper time budget to
110s, leaving the standard 15s for every other script. All tests remain
mandatory and any failure blocks the native Web export, SHA manifest creation,
GitHub master binary commit, SSH upload and public release. The source-freshness
check is unchanged. New CI contract test checks timeout, output ordering,
fail-closed status and unchanged safeguard.

Success requires real production export run, protected SSH upload with exact
seven public SHA-256, and authentic public keyboard/mobile touch drive after
publication. Neither a green unit contract nor an existing R42 PR's local
WebGL screenshot is enough to declare the game deployed.
