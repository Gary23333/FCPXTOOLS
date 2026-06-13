const state = {
  rootPath: null,
  scan: null,
  busy: false
};

const chooseBtn = document.querySelector('#chooseBtn');
const rescanBtn = document.querySelector('#rescanBtn');
const cleanAllBtn = document.querySelector('#cleanAllBtn');
const rootPathEl = document.querySelector('#rootPath');
const totalProjectSizeEl = document.querySelector('#totalProjectSize');
const totalSizeEl = document.querySelector('#totalSize');
const projectCountEl = document.querySelector('#projectCount');
const statusTextEl = document.querySelector('#statusText');
const treeView = document.querySelector('#treeView');
const projectList = document.querySelector('#projectList');

chooseBtn.addEventListener('click', async () => {
  const selected = await window.fcpxCleaner.chooseDirectory();
  if (!selected) return;
  state.rootPath = selected;
  await scan();
});

rescanBtn.addEventListener('click', scan);

cleanAllBtn.addEventListener('click', async () => {
  if (!state.scan) return;
  const targets = state.scan.projects.flatMap((project) => project.targets);
  await cleanTargets(targets);
});

async function scan() {
  if (!state.rootPath || state.busy) return;
  setBusy(true, '扫描中');
  rootPathEl.textContent = state.rootPath;

  try {
    state.scan = await window.fcpxCleaner.scanDirectory(state.rootPath);
    render();
    statusTextEl.textContent = `完成，用时 ${(state.scan.durationMs / 1000).toFixed(1)}s`;
  } catch (error) {
    statusTextEl.textContent = '扫描失败';
    projectList.className = 'project-list empty';
    projectList.textContent = error.message;
  } finally {
    setBusy(false);
  }
}

async function cleanTargets(targets) {
  const validTargets = targets.filter((target) => target.bytes > 0);
  if (!validTargets.length || state.busy) return;

  const size = formatBytes(validTargets.reduce((sum, target) => sum + target.bytes, 0));
  const ok = confirm(`将 ${validTargets.length} 个缓存目录移到废纸篓，预计释放 ${size}。继续吗？`);
  if (!ok) return;

  setBusy(true, '清理中');
  const results = await window.fcpxCleaner.cleanTargets(validTargets);
  const failed = results.filter((item) => !item.ok);
  await scan();

  if (failed.length) {
    alert(`有 ${failed.length} 个目录清理失败，请确认权限或关闭 Final Cut Pro 后重试。`);
  }
}

function setBusy(busy, text) {
  state.busy = busy;
  chooseBtn.disabled = busy;
  rescanBtn.disabled = busy || !state.rootPath;
  cleanAllBtn.disabled = busy || !state.scan || state.scan.totalGarbageBytes === 0;
  if (text) statusTextEl.textContent = text;
}

function render() {
  totalProjectSizeEl.textContent = formatBytes(state.scan.totalProjectBytes);
  totalSizeEl.textContent = formatBytes(state.scan.totalGarbageBytes);
  projectCountEl.textContent = String(state.scan.projects.length);
  cleanAllBtn.disabled = state.scan.totalGarbageBytes === 0;
  rescanBtn.disabled = false;

  renderTree();
  renderProjects();
}

function renderTree() {
  treeView.className = 'tree';
  treeView.replaceChildren(renderTreeNode(state.scan.tree));
}

function renderTreeNode(node) {
  const wrapper = document.createElement('div');
  wrapper.className = 'tree-node';

  const row = document.createElement('div');
  row.className = 'tree-row';

  const icon = document.createElement('span');
  icon.textContent = iconForNode(node);
  row.append(icon);

  const name = document.createElement('strong');
  name.textContent = node.name;
  name.title = node.path;
  row.append(name);

  if (node.fcpxItems?.length) {
    const badge = document.createElement('span');
    badge.className = 'badge';
    badge.textContent = `${node.fcpxItems.length} 项`;
    row.append(badge);
  }

  const totalBytes = node.fcpxItems?.reduce((sum, item) => sum + item.totalBytes, 0) || 0;
  const garbageBytes = node.fcpxItems?.reduce((sum, item) => sum + item.garbageBytes, 0) || 0;
  if (totalBytes > 0) {
    const size = document.createElement('span');
    size.className = 'size';
    size.textContent = `${formatBytes(totalBytes)} / 可清 ${formatBytes(garbageBytes)}`;
    row.append(size);
  }

  wrapper.append(row);

  for (const child of node.children || []) {
    wrapper.append(renderTreeNode(child));
  }

  return wrapper;
}

function renderProjects() {
  projectList.className = 'project-list';
  projectList.replaceChildren();

  if (!state.scan.projects.length) {
    projectList.className = 'project-list empty';
    projectList.textContent = '没有找到 FCPX 资源库、事件或旧版项目文件';
    return;
  }

  for (const project of state.scan.projects) {
    projectList.append(renderProjectCard(project));
  }
}

function renderProjectCard(project) {
  const card = document.createElement('article');
  card.className = 'project-card';

  const head = document.createElement('header');
  head.className = 'project-head';

  const titleArea = document.createElement('div');
  const title = document.createElement('h2');
  title.className = 'project-name';
  title.textContent = project.name;
  const meta = document.createElement('div');
  meta.className = 'project-path';
  meta.textContent = `${project.kind} · ${project.path}`;
  titleArea.append(title, meta);

  const sizes = document.createElement('div');
  sizes.className = 'project-sizes';
  sizes.append(renderMetric('总占用', project.totalBytes), renderMetric('可清理', project.garbageBytes));
  head.append(titleArea, sizes);
  card.append(head);

  if (project.targets.length) {
    const targets = document.createElement('div');
    targets.className = 'target-list';
    for (const target of project.targets) {
      targets.append(renderTargetRow(target));
    }
    card.append(targets);

    const actions = document.createElement('div');
    actions.className = 'card-actions';
    const cleanBtn = document.createElement('button');
    cleanBtn.className = 'danger';
    cleanBtn.textContent = '清理此项目';
    cleanBtn.addEventListener('click', () => cleanTargets(project.targets));
    actions.append(cleanBtn);
    card.append(actions);
  } else {
    const empty = document.createElement('div');
    empty.className = 'project-path';
    empty.textContent = '没有发现可清理缓存。';
    card.append(empty);
  }

  return card;
}

function renderMetric(label, bytes) {
  const metric = document.createElement('div');
  metric.className = 'project-metric';

  const labelEl = document.createElement('span');
  labelEl.textContent = label;

  const valueEl = document.createElement('strong');
  valueEl.textContent = formatBytes(bytes);

  metric.append(labelEl, valueEl);
  return metric;
}

function renderTargetRow(target) {
  const row = document.createElement('div');
  row.className = 'target-row';

  const name = document.createElement('strong');
  name.textContent = target.category || target.name;

  const pathEl = document.createElement('span');
  pathEl.className = 'target-path';
  pathEl.textContent = `${target.name} · ${target.path}`;
  pathEl.title = target.path;

  const size = document.createElement('span');
  size.textContent = formatBytes(target.bytes);

  row.append(name, pathEl, size);
  return row;
}

function iconForNode(node) {
  if (node.type === 'library') return '▣';
  if (node.type === 'legacy-project') return '▧';
  if (node.project) return '◆';
  return '▸';
}

function formatBytes(bytes) {
  if (!bytes) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** index;
  return `${value >= 10 || index === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[index]}`;
}
