import net from 'net';
import path from 'path';
import fs from 'fs';
import prettier from 'prettier';

let connCnt = 0;

const server = net.createServer((conn: net.Socket) => {
  console.log('new connection', conn.remoteAddress);
  connCnt += 1;

  conn.on('data', (msg: any) => {
    const [id, data] = JSON.parse(msg);
    console.log(data);

    if (data.cmd === 'KILL') {
      conn.end();
      return;
    }

    resolveConfig(data.path).then(options => {
      const result = prettier.format(data.source, { ...options, parser: 'typescript' });
      conn.write(JSON.stringify([id, { source: result }]));
    });
  });

  conn.on('close', () => {
    console.log('close');
    connCnt -= 1;
    if (connCnt <= 0) {
      server.close();
    }
  });
});

server.listen(4242);
console.log('server started');
server.on('close', () => {
  console.log('shutdown');
});

const resolveConfig = async (filePath: string | undefined): Promise<object> => {
  if (filePath) {
    return prettier.resolveConfig(filePath).then(options => options || {});
  }
  return {};
};
