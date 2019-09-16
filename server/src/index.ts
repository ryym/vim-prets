import net from 'net';
import path from 'path';
import fs from 'fs';
import prettier from 'prettier';

const server = net.createServer((conn: net.Socket) => {
  console.log('new connection', conn.remoteAddress);

  conn.on('data', (msg: any) => {
    const [id, data] = JSON.parse(msg);
    console.log(data);

    const confPath = findConfPath(path.dirname(data.path))
    let options = {}
    if (confPath != null) {
      options = require(confPath)
    }

    const result = prettier.format(data.source, { ...options, parser: 'typescript' });
    conn.write(JSON.stringify([id, { source: result }]));
  });

  conn.on('close', () => {
    console.log('close');
  });
});

server.listen(4242);

// TODO: Use Prettier API to resolve configuration.
const findConfPath = (dir: string): string | null => {
  const confPath = path.join(dir, '.prettierrc')
  if (fs.existsSync(confPath)) {
    return confPath
  }
  const parentDir = path.dirname(dir) 
  if (parentDir == dir) {
    return null
  } else {
    return findConfPath(parentDir)
  }
};
