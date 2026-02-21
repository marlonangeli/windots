# Windows Sandbox

Use the sample `.wsb` to validate fresh-machine behavior.

## Steps
1. Edit mapped folder host path in `windots-bootstrap.wsb`.
2. Launch the `.wsb` file.
3. Inside Sandbox, run:
   - `pwsh -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\WDAGUtilityAccount\\Desktop\\windots\\tests\\sandbox\\run-bootstrap.ps1`

The script should complete install/bootstrap/validation without manual remediation.
