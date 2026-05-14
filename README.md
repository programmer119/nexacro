# Manufacturing Monitoring XFDL Prototype

Nexacro-style manufacturing monitoring prototype for legacy data integration and visualization.

## What This Shows

- `MonitoringDashboard.xfdl`: Nexacro Form/Dataset/Grid/Button/Chart-style source file
- `build/`: browser-runnable static build generated from the XFDL concept
- Legacy source examples from MES, ERP, and equipment gateway
- Processing flow examples for collection, cleansing, aggregation, threshold checks, and alarms

## Local Preview

Open the build output through any static server:

```bash
node server.js
```

Then open:

```text
http://127.0.0.1:4589/build/
```

## GitHub Pages

This repository includes a GitHub Actions workflow that deploys the `build/` directory to GitHub Pages.

