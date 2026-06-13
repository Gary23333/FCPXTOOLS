const path = require('path');
const fs = require('fs/promises');

const GENERATED_DIR_NAMES = new Set([
  'Render Files',
  'Analysis Files',
  'Waveform Cache Files',
  'Thumbnail Media',
  'Shared Items'
]);

const GENERATED_PAIR_NAMES = new Set([
  path.join('Transcoded Media', 'High Quality Media'),
  path.join('Transcoded Media', 'Proxy Media')
]);

const FCPX_EXTENSIONS = new Set(['.fcpbundle', '.fcpproject']);
const EVENT_DB_NAME = 'CurrentVersion.fcpevent';

async function scanRoot(rootPath) {
  const rootStat = await fs.stat(rootPath);
  if (!rootStat.isDirectory()) throw new Error('请选择一个目录。');

  const startedAt = Date.now();
  const tree = await scanDirectoryNode(rootPath, null);
  const projects = flattenProjects(tree);
  const totalGarbageBytes = projects.reduce((sum, item) => sum + item.garbageBytes, 0);
  const totalProjectBytes = projects.reduce((sum, item) => sum + item.totalBytes, 0);

  return {
    rootPath,
    tree,
    projects,
    totalProjectBytes,
    totalGarbageBytes,
    scannedAt: new Date().toISOString(),
    durationMs: Date.now() - startedAt
  };
}

async function scanDirectoryNode(dirPath, parentProjectPath) {
  const name = path.basename(dirPath) || dirPath;
  const ext = path.extname(name).toLowerCase();
  const isLibrary = ext === '.fcpbundle';
  const isLegacyProject = ext === '.fcpproject';
  const projectRoot = isLibrary || isLegacyProject ? dirPath : parentProjectPath;

  const node = {
    name,
    path: dirPath,
    type: isLibrary ? 'library' : isLegacyProject ? 'legacy-project' : 'directory',
    children: [],
    fcpxItems: [],
    project: null
  };

  let entries = [];
  try {
    entries = await fs.readdir(dirPath, { withFileTypes: true });
  } catch (error) {
    node.error = error.message;
    return node;
  }

  const fileNames = new Set(entries.map((entry) => entry.name));
  const hasStandaloneEvent = fileNames.has(EVENT_DB_NAME) && !parentProjectPath;
  if (isLibrary || isLegacyProject || hasStandaloneEvent) {
    node.project = await buildProjectSummary(dirPath, isLibrary ? 'FCPX 资源库' : isLegacyProject ? '旧版项目' : 'FCPX 事件');
    node.fcpxItems.push(node.project);
  }

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'zh-Hans-CN'))) {
    const childPath = path.join(dirPath, entry.name);
    if (entry.isSymbolicLink()) continue;

    if (entry.isDirectory()) {
      const child = await scanDirectoryNode(childPath, projectRoot);
      node.children.push(child);
      node.fcpxItems.push(...child.fcpxItems);
      continue;
    }

    if (entry.isFile() && entry.name === EVENT_DB_NAME && !node.project && !parentProjectPath) {
      const summary = await buildProjectSummary(dirPath, 'FCPX 事件');
      node.project = summary;
      node.fcpxItems.push(summary);
    }
  }

  return node;
}

async function buildProjectSummary(projectPath, kind) {
  const totalBytes = await getDirectorySize(projectPath);
  const targets = await findGeneratedTargets(projectPath);
  const garbageBytes = targets.reduce((sum, target) => sum + target.bytes, 0);

  return {
    id: projectPath,
    name: path.basename(projectPath),
    path: projectPath,
    kind,
    totalBytes,
    garbageBytes,
    targets
  };
}

async function findGeneratedTargets(projectPath) {
  const targets = [];

  async function walk(currentPath) {
    let entries = [];
    try {
      entries = await fs.readdir(currentPath, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory() || entry.isSymbolicLink()) continue;

      const childPath = path.join(currentPath, entry.name);
      if (isNestedFcpxContainer(childPath, projectPath)) continue;

      if (isGeneratedDirectory(childPath, projectPath)) {
        const bytes = await getDirectorySize(childPath);
        targets.push({
          name: labelGeneratedDirectory(childPath),
          category: categoryForGeneratedDirectory(childPath),
          path: childPath,
          bytes
        });
        continue;
      }

      await walk(childPath);
    }
  }

  await walk(projectPath);
  return targets.sort((a, b) => b.bytes - a.bytes);
}

function isNestedFcpxContainer(candidatePath, rootPath) {
  if (candidatePath === rootPath) return false;
  return FCPX_EXTENSIONS.has(path.extname(candidatePath).toLowerCase());
}

function isGeneratedDirectory(candidatePath, rootPath) {
  const name = path.basename(candidatePath);
  if (GENERATED_DIR_NAMES.has(name)) return true;

  const relativeParts = path.relative(rootPath, candidatePath).split(path.sep);
  if (relativeParts.length >= 2) {
    const pair = path.join(relativeParts[relativeParts.length - 2], relativeParts[relativeParts.length - 1]);
    return GENERATED_PAIR_NAMES.has(pair);
  }

  return false;
}

function labelGeneratedDirectory(targetPath) {
  const name = path.basename(targetPath);
  const parent = path.basename(path.dirname(targetPath));
  if (parent === 'Transcoded Media') return `${parent} / ${name}`;
  return name;
}

function categoryForGeneratedDirectory(targetPath) {
  const name = path.basename(targetPath);
  const parent = path.basename(path.dirname(targetPath));

  if (name === 'Render Files') return '渲染文件';
  if (parent === 'Transcoded Media' && name === 'High Quality Media') return '优化媒体';
  if (parent === 'Transcoded Media' && name === 'Proxy Media') return '代理媒体';
  if (name === 'Analysis Files') return '分析文件';
  if (name === 'Waveform Cache Files') return '波形缓存';
  if (name === 'Thumbnail Media') return '缩略图缓存';
  if (name === 'Shared Items') return '共享/导出文件';

  return '可清理文件';
}

async function getDirectorySize(dirPath) {
  let total = 0;
  let entries = [];
  try {
    entries = await fs.readdir(dirPath, { withFileTypes: true });
  } catch {
    return 0;
  }

  for (const entry of entries) {
    const childPath = path.join(dirPath, entry.name);
    if (entry.isSymbolicLink()) continue;
    try {
      if (entry.isDirectory()) {
        total += await getDirectorySize(childPath);
      } else if (entry.isFile()) {
        const stat = await fs.stat(childPath);
        total += stat.size;
      }
    } catch {
      // Files can disappear while FCPX is writing; ignore and continue scanning.
    }
  }

  return total;
}

function flattenProjects(tree) {
  const projects = [];

  function visit(node) {
    if (node.project) projects.push(node.project);
    for (const child of node.children || []) visit(child);
  }

  visit(tree);
  return projects.sort((a, b) => b.garbageBytes - a.garbageBytes);
}

module.exports = {
  scanRoot,
  findGeneratedTargets,
  formatBytesForTest: (bytes) => bytes
};
