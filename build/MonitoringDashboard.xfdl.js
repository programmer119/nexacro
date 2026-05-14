window.NEXACRO_BUILD_MANIFEST = {
  application: "ManufacturingMonitoring",
  form: "MonitoringDashboard",
  source: "MonitoringDashboard.xfdl",
  generatedBy: "Codex mini XFDL build",
  runtime: "xfdl-runtime.js",
  datasets: [
    "dsEquipment",
    "dsTrend",
    "dsAlarm",
    "dsInterfaceLog",
    "dsProcessResult",
    "dsLegacyRaw"
  ],
  services: [
    {
      id: "searchMonitoring",
      url: "/monitoring/selectLegacyMonitoring.do",
      description: "레거시 시스템 데이터 연동 및 처리 결과 조회"
    }
  ]
};
