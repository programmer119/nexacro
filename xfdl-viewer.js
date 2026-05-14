const app = document.querySelector("#app");
const loading = document.querySelector("#loading");

const state = {
  xml: null,
  datasets: new Map(),
  controls: new Map()
};

boot();

async function boot() {
  const text = await fetch("MonitoringDashboard.xfdl").then((res) => res.text());
  state.xml = new DOMParser().parseFromString(text, "application/xml");
  loadDatasets();
  renderForm();
  attachEvents();
  runSampleLogic();
  loading.remove();
  resizeCanvas();
  window.addEventListener("resize", resizeCanvas);
}

function loadDatasets() {
  state.xml.querySelectorAll("Objects > Dataset").forEach((dataset) => {
    const id = dataset.getAttribute("id");
    const columns = Array.from(dataset.querySelectorAll("ColumnInfo > Column")).map((col) => col.getAttribute("id"));
    const rows = Array.from(dataset.querySelectorAll(":scope > Rows > Row")).map((row) => {
      const item = {};
      columns.forEach((column) => {
        const col = Array.from(row.querySelectorAll("Col")).find((node) => node.getAttribute("id") === column);
        item[column] = col ? col.textContent : "";
      });
      return item;
    });
    state.datasets.set(id, { columns, rows });
  });
}

function renderForm() {
  const form = state.xml.querySelector("Form");
  const root = document.createElement("div");
  root.className = "xfdl-form";
  root.style.width = px(form.getAttribute("width"));
  root.style.height = px(form.getAttribute("height"));
  app.append(root);

  const layout = form.querySelector(":scope > Layouts > Layout");
  Array.from(layout.children).forEach((node) => renderNode(node, root));

  const note = document.createElement("div");
  note.className = "viewer-note";
  note.textContent = "MonitoringDashboard.xfdl을 브라우저에서 해석해 렌더링한 화면";
  document.body.append(note);
}

function renderNode(node, parent) {
  const tag = node.tagName;
  if (tag === "Div") {
    const div = makeBase(node, "div", "xfdl-div");
    applyBoxStyle(div, node);
    parent.append(div);
    const layout = node.querySelector(":scope > Layouts > Layout");
    if (layout) Array.from(layout.children).forEach((child) => renderNode(child, div));
    return div;
  }

  if (tag === "Static") {
    const el = makeBase(node, "div", "xfdl-static");
    el.textContent = node.getAttribute("text") || "";
    applyTextStyle(el, node);
    parent.append(el);
    return el;
  }

  if (tag === "Combo") {
    const el = makeBase(node, "select", "xfdl-combo");
    const dataset = state.datasets.get(node.getAttribute("innerdataset"));
    const codeColumn = node.getAttribute("codecolumn");
    const dataColumn = node.getAttribute("datacolumn");
    if (dataset) {
      dataset.rows.forEach((row) => {
        const option = document.createElement("option");
        option.value = row[codeColumn];
        option.textContent = row[dataColumn];
        el.append(option);
      });
    }
    parent.append(el);
    return el;
  }

  if (tag === "Calendar") {
    const el = makeBase(node, "input", "xfdl-calendar");
    el.type = "date";
    el.value = new Date().toISOString().slice(0, 10);
    parent.append(el);
    return el;
  }

  if (tag === "Button") {
    const el = makeBase(node, "button", "xfdl-button");
    el.textContent = node.getAttribute("text") || "";
    if ((node.getAttribute("background") || "").toLowerCase() === "#0f766e") el.classList.add("primary");
    parent.append(el);
    return el;
  }

  if (tag === "Grid") {
    const el = makeBase(node, "div", "xfdl-grid");
    el.dataset.binddataset = node.getAttribute("binddataset");
    parent.append(el);
    renderGrid(node, el);
    return el;
  }

  if (tag === "BasicChart") {
    const canvas = makeBase(node, "canvas", "xfdl-chart");
    canvas.width = Number(node.getAttribute("width") || 780);
    canvas.height = Number(node.getAttribute("height") || 184);
    canvas.dataset.binddataset = node.getAttribute("binddataset");
    parent.append(canvas);
    return canvas;
  }
}

function makeBase(node, tagName, className) {
  const el = document.createElement(tagName);
  el.className = className;
  const id = node.getAttribute("id");
  if (id) {
    el.id = id;
    state.controls.set(id, el);
  }
  ["left", "top", "width", "height"].forEach((attr) => {
    const value = node.getAttribute(attr);
    if (value !== null) el.style[attr] = px(value);
  });
  return el;
}

function applyBoxStyle(el, node) {
  const bg = node.getAttribute("background");
  const border = node.getAttribute("border");
  if (bg) el.style.background = bg;
  if (border) el.style.border = border;
}

function applyTextStyle(el, node) {
  const color = node.getAttribute("color");
  const font = node.getAttribute("font");
  if (color) el.style.color = color;
  if (font) {
    const sizeMatch = font.match(/(\d+)px/);
    if (sizeMatch) el.style.fontSize = `${sizeMatch[1]}px`;
    if (font.includes("bold")) el.style.fontWeight = "700";
  }
}

function renderGrid(node, target, overrideRows) {
  const datasetId = node.getAttribute("binddataset");
  const dataset = state.datasets.get(datasetId);
  const rows = overrideRows || dataset?.rows || [];
  const headCells = Array.from(node.querySelectorAll("Band#head Cell")).sort(byCol);
  const bodyCells = Array.from(node.querySelectorAll("Band#body Cell")).sort(byCol);
  const table = document.createElement("table");

  if (headCells.length) {
    const thead = document.createElement("thead");
    const tr = document.createElement("tr");
    headCells.forEach((cell) => {
      const th = document.createElement("th");
      th.textContent = cell.getAttribute("text") || "";
      tr.append(th);
    });
    thead.append(tr);
    table.append(thead);
  }

  const tbody = document.createElement("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    bodyCells.forEach((cell) => {
      const td = document.createElement("td");
      const key = (cell.getAttribute("text") || "").replace("bind:", "");
      td.textContent = row[key] ?? "";
      if (td.textContent === "정상") td.className = "state-normal";
      if (td.textContent === "주의") td.className = "state-warn";
      if (td.textContent === "정지") td.className = "state-stop";
      tr.append(td);
    });
    tbody.append(tr);
  });
  table.append(tbody);
  target.replaceChildren(table);
}

function attachEvents() {
  state.controls.get("btnSearch")?.addEventListener("click", runSampleLogic);
  state.controls.get("btnReset")?.addEventListener("click", () => {
    state.controls.get("cboPlant").value = "ALL";
    state.controls.get("cboLine").value = "ALL";
    state.controls.get("cboState").value = "ALL";
    state.controls.get("calBaseDate").value = new Date().toISOString().slice(0, 10);
    runSampleLogic();
  });
}

function runSampleLogic() {
  const equipmentRows = [
    { plant: "GEOJE-1", line: "A", eqId: "EQ-A-101", eqName: "절단기 1호", state: "정상", runRate: 94, output: 1280, defect: 8, collectedAt: "09:12:18" },
    { plant: "GEOJE-1", line: "A", eqId: "EQ-A-102", eqName: "용접 로봇 2호", state: "주의", runRate: 78, output: 990, defect: 21, collectedAt: "09:12:15" },
    { plant: "GEOJE-1", line: "B", eqId: "EQ-B-201", eqName: "도장 부스 1호", state: "정상", runRate: 91, output: 870, defect: 11, collectedAt: "09:12:11" },
    { plant: "GEOJE-2", line: "A", eqId: "EQ-A-211", eqName: "크레인 센서", state: "정지", runRate: 0, output: 0, defect: 0, collectedAt: "09:09:40" },
    { plant: "GEOJE-2", line: "C", eqId: "EQ-C-231", eqName: "압력 테스트기", state: "주의", runRate: 73, output: 680, defect: 19, collectedAt: "09:12:03" }
  ];

  const plant = state.controls.get("cboPlant").value;
  const line = state.controls.get("cboLine").value;
  const status = state.controls.get("cboState").value;
  const filtered = equipmentRows.filter((row) => {
    return (plant === "ALL" || row.plant === plant)
      && (line === "ALL" || row.line === line)
      && (status === "ALL" || row.state === status);
  });

  const output = filtered.reduce((sum, row) => sum + Number(row.output), 0);
  const defect = filtered.reduce((sum, row) => sum + Number(row.defect), 0);
  const runRate = filtered.length ? filtered.reduce((sum, row) => sum + Number(row.runRate), 0) / filtered.length : 0;
  const alarms = filtered.filter((row) => row.state !== "정상").length;

  setText("staRunRateValue", `${runRate.toFixed(1)}%`);
  setText("staOutputValue", output.toLocaleString("ko-KR"));
  setText("staDefectValue", `${(output ? defect / output * 100 : 0).toFixed(2)}%`);
  setText("staAlarmValue", String(alarms));

  renderGridFromId("grdEquipment", filtered);
  renderGridFromId("grdLineState", buildLineRows(filtered));
  renderGridFromId("grdAlarm", [
    { time: "09:09", level: "정지", title: "EQ-A-211 데이터 수집 중단", desc: "레거시 설비 게이트웨이 응답 없음" },
    { time: "09:07", level: "주의", title: "EQ-A-102 용접 온도 임계치 접근", desc: "최근 5분 평균 온도 87도" }
  ]);
  const interfaceRows = [
    { systemName: "MES", interfaceType: "Oracle DB Link", recordCount: 2418, state: "정상", lastSync: "2026-05-14 09:12:20" },
    { systemName: "ERP", interfaceType: "Batch Table", recordCount: 386, state: "정상", lastSync: "2026-05-14 09:10:02" },
    { systemName: "설비 Gateway", interfaceType: "REST Adapter", recordCount: 128, state: "주의", lastSync: "2026-05-14 09:09:40" }
  ];
  const legacyRawRows = [
    { sourceSystem: "MES", legacyKey: "PROD_ACT_20260514_0912", eqCode: "EQ-A-101", tagCode: "GOOD_QTY", rawValue: "1280", unit: "EA", quality: "GOOD", receivedAt: "09:12:20", mappedField: "dsEquipment.output" },
    { sourceSystem: "설비 Gateway", legacyKey: "PLC_A102_TEMP_0907", eqCode: "EQ-A-102", tagCode: "WELD_TEMP", rawValue: "87.4", unit: "C", quality: "WARN", receivedAt: "09:07:03", mappedField: "dsAlarm.title / dsEquipment.state" },
    { sourceSystem: "ERP", legacyKey: "WORK_ORDER_77821", eqCode: "EQ-B-201", tagCode: "PLAN_QTY", rawValue: "920", unit: "EA", quality: "GOOD", receivedAt: "09:10:02", mappedField: "생산 계획 대비 실적 계산" }
  ];
  renderGridFromId("grdInterfaceLog", interfaceRows);
  renderGridFromId("grdLegacyRaw", legacyRawRows);
  renderGridFromId("grdProcessResult", buildProcessRows(legacyRawRows, filtered));
  drawChart();
}

function renderGridFromId(id, rows) {
  const grid = state.controls.get(id);
  const node = state.xml.querySelector(`Grid[id="${id}"]`);
  if (grid && node) renderGrid(node, grid, rows);
}

function buildLineRows(rows) {
  return ["A", "B", "C"].map((line) => {
    const lineRows = rows.filter((row) => row.line === line);
    const stateText = lineRows.some((row) => row.state === "정지") ? "정지" : lineRows.some((row) => row.state === "주의") ? "주의" : lineRows.length ? "정상" : "-";
    const runRate = lineRows.length ? lineRows.reduce((sum, row) => sum + Number(row.runRate), 0) / lineRows.length : 0;
    const output = lineRows.reduce((sum, row) => sum + Number(row.output), 0);
    return { line: `${line}라인`, state: stateText, runRate: `${runRate.toFixed(1)}%`, output: output.toLocaleString("ko-KR") };
  });
}

function buildProcessRows(interfaceRows, equipmentRows) {
  const rawCount = interfaceRows.reduce((sum, row) => sum + Number(row.recordCount), 0);
  const alarmCount = equipmentRows.filter((row) => Number(row.runRate) < 80 || row.state !== "정상").length;
  return [
    { stepName: "원천 수집", inputCount: rawCount, outputCount: rawCount, result: "정상", remark: "MES/ERP/설비 Gateway 수집" },
    { stepName: "데이터 정제", inputCount: rawCount, outputCount: equipmentRows.length, result: "정상", remark: "설비별 최신값 기준 병합" },
    { stepName: "임계치 판정", inputCount: equipmentRows.length, outputCount: alarmCount, result: alarmCount ? "주의" : "정상", remark: "가동률 80% 미만 또는 상태 이상" }
  ];
}

function drawChart() {
  const canvas = state.controls.get("chtTrend");
  const ctx = canvas.getContext("2d");
  const values = [310, 520, 740, 880, 820, 940, 760, 910];
  const labels = ["06", "07", "08", "09", "10", "11", "12", "13"];
  const max = Math.max(...values);
  const pad = 28;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = "#e5e7eb";
  for (let i = 0; i < 4; i += 1) {
    const y = pad + ((canvas.height - pad * 2) / 3) * i;
    ctx.beginPath();
    ctx.moveTo(pad, y);
    ctx.lineTo(canvas.width - pad, y);
    ctx.stroke();
  }
  ctx.strokeStyle = "#0f766e";
  ctx.lineWidth = 3;
  ctx.beginPath();
  values.forEach((value, index) => {
    const x = pad + ((canvas.width - pad * 2) / (values.length - 1)) * index;
    const y = canvas.height - pad - (value / max) * (canvas.height - pad * 2);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();
  ctx.fillStyle = "#475569";
  ctx.font = "12px Segoe UI";
  ctx.textAlign = "center";
  labels.forEach((label, index) => {
    const x = pad + ((canvas.width - pad * 2) / (labels.length - 1)) * index;
    ctx.fillText(`${label}시`, x, canvas.height - 8);
  });
}

function setText(id, value) {
  const el = state.controls.get(id);
  if (el) el.textContent = value;
}

function resizeCanvas() {
  const scale = Math.min(1, window.innerWidth / 1280);
  app.style.transform = `scale(${scale})`;
  app.style.height = `${1120 * scale}px`;
}

function px(value) {
  return `${Number(value || 0)}px`;
}

function byCol(a, b) {
  return Number(a.getAttribute("col") || 0) - Number(b.getAttribute("col") || 0);
}
