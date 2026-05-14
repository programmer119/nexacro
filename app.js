const equipment = [
  { plant: "GEOJE-1", line: "A", id: "EQ-A-101", name: "절단기 1호", state: "정상", runRate: 94, output: 1280, defect: 8, collectedAt: "09:12:18" },
  { plant: "GEOJE-1", line: "A", id: "EQ-A-102", name: "용접 로봇 2호", state: "주의", runRate: 78, output: 990, defect: 21, collectedAt: "09:12:15" },
  { plant: "GEOJE-1", line: "B", id: "EQ-B-201", name: "도장 부스 1호", state: "정상", runRate: 91, output: 870, defect: 11, collectedAt: "09:12:11" },
  { plant: "GEOJE-1", line: "C", id: "EQ-C-301", name: "검사 장비 1호", state: "정상", runRate: 88, output: 740, defect: 5, collectedAt: "09:12:09" },
  { plant: "GEOJE-2", line: "A", id: "EQ-A-211", name: "크레인 센서", state: "정지", runRate: 0, output: 0, defect: 0, collectedAt: "09:09:40" },
  { plant: "GEOJE-2", line: "B", id: "EQ-B-221", name: "조립 컨베이어", state: "정상", runRate: 96, output: 1430, defect: 7, collectedAt: "09:12:20" },
  { plant: "GEOJE-2", line: "C", id: "EQ-C-231", name: "압력 테스트기", state: "주의", runRate: 73, output: 680, defect: 19, collectedAt: "09:12:03" }
];

const trend = [
  { hour: "06", output: 310 },
  { hour: "07", output: 520 },
  { hour: "08", output: 740 },
  { hour: "09", output: 880 },
  { hour: "10", output: 820 },
  { hour: "11", output: 940 },
  { hour: "12", output: 760 },
  { hour: "13", output: 910 },
  { hour: "14", output: 1030 },
  { hour: "15", output: 980 }
];

const alarms = [
  { time: "09:09", level: "정지", title: "EQ-A-211 데이터 수집 중단", desc: "레거시 설비 게이트웨이 응답 없음" },
  { time: "09:07", level: "주의", title: "EQ-A-102 용접 온도 임계치 접근", desc: "최근 5분 평균 온도 87도" },
  { time: "08:54", level: "주의", title: "EQ-C-231 불량률 증가", desc: "기준 불량률 대비 2.1%p 상승" },
  { time: "08:31", level: "정상", title: "Oracle 배치 연동 완료", desc: "생산 실적 2,418건 반영" }
];

const plantFilter = document.querySelector("#plantFilter");
const lineFilter = document.querySelector("#lineFilter");
const stateFilter = document.querySelector("#stateFilter");
const baseDate = document.querySelector("#baseDate");

document.querySelector("#searchBtn").addEventListener("click", render);
document.querySelector("#resetBtn").addEventListener("click", () => {
  plantFilter.value = "ALL";
  lineFilter.value = "ALL";
  stateFilter.value = "ALL";
  baseDate.value = new Date().toISOString().slice(0, 10);
  render();
});

baseDate.value = new Date().toISOString().slice(0, 10);
render();

function getFilteredRows() {
  return equipment.filter((row) => {
    return (plantFilter.value === "ALL" || row.plant === plantFilter.value)
      && (lineFilter.value === "ALL" || row.line === lineFilter.value)
      && (stateFilter.value === "ALL" || row.state === stateFilter.value);
  });
}

function render() {
  const rows = getFilteredRows();
  renderKpis(rows);
  renderLineStatus(rows);
  renderTable(rows);
  renderAlarms();
  drawTrendChart(rows);
}

function renderKpis(rows) {
  const runRate = average(rows.map((row) => row.runRate));
  const output = rows.reduce((sum, row) => sum + row.output, 0);
  const defect = rows.reduce((sum, row) => sum + row.defect, 0);
  const defectRate = output > 0 ? (defect / output) * 100 : 0;
  const alarmCount = rows.filter((row) => row.state !== "정상").length;

  document.querySelector("#kpiRunRate").textContent = `${runRate.toFixed(1)}%`;
  document.querySelector("#kpiOutput").textContent = output.toLocaleString("ko-KR");
  document.querySelector("#kpiDefect").textContent = `${defectRate.toFixed(2)}%`;
  document.querySelector("#kpiAlarm").textContent = alarmCount.toString();
}

function renderLineStatus(rows) {
  const target = document.querySelector("#lineStatus");
  const groups = ["A", "B", "C"].map((line) => {
    const lineRows = rows.filter((row) => row.line === line);
    const hasStop = lineRows.some((row) => row.state === "정지");
    const hasWarn = lineRows.some((row) => row.state === "주의");
    const state = hasStop ? "정지" : hasWarn ? "주의" : lineRows.length ? "정상" : "대상없음";
    return {
      line,
      state,
      runRate: average(lineRows.map((row) => row.runRate)),
      output: lineRows.reduce((sum, row) => sum + row.output, 0)
    };
  });

  target.innerHTML = groups.map((group) => `
    <div class="line-card">
      <div class="line-badge">${group.line}</div>
      <div>
        <strong>${group.line}라인</strong>
        <span>가동률 ${group.runRate.toFixed(1)}% · 생산 ${group.output.toLocaleString("ko-KR")}</span>
      </div>
      <span class="state-pill ${stateClass(group.state)}">${group.state}</span>
    </div>
  `).join("");

  const normalCount = groups.filter((group) => group.state === "정상").length;
  document.querySelector("#stateSummary").textContent = `정상 ${normalCount} / 전체 ${groups.length}`;
}

function renderTable(rows) {
  const target = document.querySelector("#equipmentRows");
  target.innerHTML = rows.map((row) => `
    <tr>
      <td>${row.plant}</td>
      <td>${row.line}라인</td>
      <td>${row.id}</td>
      <td>${row.name}</td>
      <td><span class="state-pill ${stateClass(row.state)}">${row.state}</span></td>
      <td class="num">${row.runRate}%</td>
      <td class="num">${row.output.toLocaleString("ko-KR")}</td>
      <td class="num">${row.defect}</td>
      <td>${row.collectedAt}</td>
    </tr>
  `).join("");

  document.querySelector("#gridCount").textContent = `${rows.length}건`;
}

function renderAlarms() {
  const target = document.querySelector("#alarmList");
  target.innerHTML = alarms.map((alarm) => `
    <div class="alarm-item">
      <div class="alarm-time">${alarm.time}</div>
      <div>
        <div class="alarm-title">${alarm.title}</div>
        <div class="alarm-desc">${alarm.desc}</div>
      </div>
      <span class="state-pill ${stateClass(alarm.level)}">${alarm.level}</span>
    </div>
  `).join("");
}

function drawTrendChart(rows) {
  const canvas = document.querySelector("#trendChart");
  const ctx = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  const padding = 42;
  const totalRate = rows.length ? rows.reduce((sum, row) => sum + row.runRate, 0) / rows.length : 0;
  const adjusted = trend.map((item, index) => ({
    hour: item.hour,
    output: Math.round(item.output * (0.72 + totalRate / 280) + index * 8)
  }));
  const max = Math.max(...adjusted.map((item) => item.output), 100);

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, width, height);

  ctx.strokeStyle = "#e5e7eb";
  ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i += 1) {
    const y = padding + ((height - padding * 2) / 4) * i;
    ctx.beginPath();
    ctx.moveTo(padding, y);
    ctx.lineTo(width - padding, y);
    ctx.stroke();
  }

  ctx.strokeStyle = "#0f766e";
  ctx.lineWidth = 3;
  ctx.beginPath();
  adjusted.forEach((item, index) => {
    const x = padding + ((width - padding * 2) / (adjusted.length - 1)) * index;
    const y = height - padding - (item.output / max) * (height - padding * 2);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  adjusted.forEach((item, index) => {
    const x = padding + ((width - padding * 2) / (adjusted.length - 1)) * index;
    const y = height - padding - (item.output / max) * (height - padding * 2);
    ctx.fillStyle = "#0f766e";
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#475569";
    ctx.font = "12px Segoe UI";
    ctx.textAlign = "center";
    ctx.fillText(`${item.hour}시`, x, height - 14);
  });

  document.querySelector("#chartSummary").textContent = `최대 ${max.toLocaleString("ko-KR")}건`;
}

function average(values) {
  if (!values.length) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function stateClass(state) {
  if (state === "정상") return "state-ok";
  if (state === "주의") return "state-warn";
  if (state === "정지") return "state-stop";
  return "";
}
