#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const prettier = require('prettier');

const main = async (args) => {
  const input = tryJsonParse(args[0]);
  if (input === undefined) {
    return respondError('failed to parse input');
  }

  if (input.source == null || input.path == null || input.filetype == null || input.bufnr == null) {
    return respondError('invalid input JSON');
  }

  const ignorePath = findIgnoreFile(input.path);

  const [options, info] = await Promise.all([
    resolveConfig(input.path),
    prettier.getFileInfo(input.path, { ignorePath }),
  ]);

  if (info.ignored && !input.include_ignore) {
    return respond('Ok', { ignored: true });
  }

  const parser = getParserForFileType(input.filetype) || info.inferredParser;
  if (parser == null) {
    return respondError('could not infer parser');
  }

  const formatted = prettier.format(input.source, { ...options, endOfLine: 'lf', parser });
  respond('Ok', { source: formatted, bufnr: input.bufnr });
};

const tryJsonParse = (input) => {
  try {
    return JSON.parse(input);
  } catch (err) {
    return undefined;
  }
};

const resolveConfig = async (filePath) => {
  if (filePath) {
    return prettier.resolveConfig(filePath).then((options) => options || {});
  }
  return {};
};

const getParserForFileType = (filetype) => {
  switch (filetype) {
    case 'javascript':
    case 'javascript.jsx':
      return 'babel';
    case 'typescript':
      return 'typescript';
    case 'css':
      return 'css';
    case 'scss':
      return 'scss';
    case 'less':
      return 'less';
    case 'json':
      return 'json';
    case 'json5':
      return 'json5';
    case 'graphql':
      return 'graphql';
    case 'markdown':
      return 'markdown';
    case 'html':
      return 'html';
    case 'vue':
      return 'vue';
    case 'yaml':
      return 'yaml';
    default:
      return null;
  }
};

const findIgnoreFile = (filePath, nTries = 0) => {
  if (nTries >= 100) {
    throw new Error('failed to find ignore path (cannot detect root directory)');
  }
  const dir = path.dirname(filePath);
  if (dir === path.dirname(dir)) {
    return null; // root
  }
  const candidatePath = path.join(dir, '.prettierignore');
  if (fs.existsSync(candidatePath)) {
    return candidatePath;
  }
  return findIgnoreFile(dir, nTries + 1);
};

const respondError = (message) => {
  return respond('Error', { message });
};

const respond = (type, payload) => {
  console.log(JSON.stringify({ type, payload }));
};

main(process.argv.slice(2)).catch((err) => {
  respondError(err.message || 'unexpected error occurred');
});
