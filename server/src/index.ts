import net from 'net';
import path from 'path';
import { promisify } from 'util';
import fs from 'fs';
import prettier from 'prettier';

let connCnt = 0;

const appendFile = promisify(fs.appendFile);

// from server/dist/lib
const pluginRoot = path.resolve(__dirname, '..', '..', '..');
const logDir = `${pluginRoot}/log`;

const log = async (msg: any) => {
  console.log(msg);

  // const now = new Date();
  // const year = now.getFullYear();
  // let month = String(now.getMonth() + 1);
  // let date = String(now.getDate());
  // if (month < '10') {
  //   month = '0' + month;
  // }
  // if (date < '10') {
  //   date = '0' + date;
  // }

  // const fileName = `${logDir}/${year}${month}${date}`;
  // if (typeof msg !== 'string') {
  //   msg = JSON.stringify(msg);
  // }
  // return appendFile(fileName, msg + '\n');
};

const main = () => {
  const server = net.createServer(conn => {
    handleConnection(server, conn);
  });

  const alive = path.join(pluginRoot, '.alive');

  fs.writeFileSync(alive, process.pid);

  server.listen(4242);

  log('server started');
  server.on('close', async () => {
    await log('shutdown');
    fs.unlinkSync(alive);
  });

  process.on('SIGINT', async () => {
    await log('shutdown by SIGINT');
    if (fs.existsSync(alive)) {
      fs.unlinkSync(alive);
    }
    process.exit();
  });
};

const resolveConfig = async (filePath: string | undefined): Promise<object> => {
  if (filePath) {
    return prettier.resolveConfig(filePath).then(options => options || {});
  }
  return {};
};

const handleConnection = (server: net.Server, conn: net.Socket): void => {
  connCnt += 1;
  log(`new connection. connCnt: ${connCnt}`);

  conn.on('data', async (msg: any) => {
    const [id, data] = JSON.parse(msg);
    log(data);

    if (data.cmd === 'KILL') {
      conn.end();
      return;
    }

    const [options, info] = await Promise.all([
      resolveConfig(data.path),
      prettier.getFileInfo(data.path),
    ]);

    if (info.inferredParser == null) {
      log('could not infer parser');
      conn.write(JSON.stringify([id, { message: 'could not infer parser' }]));
      return;
    }

    try {
      const result = prettier.format(data.source, {
        ...options,
        endOfLine: 'lf',
        parser: info.inferredParser as any,
      });
      conn.write(JSON.stringify([id, { bufnr: data.bufnr, source: result }]));
    } catch (err) {
      const message = err.message || 'unexpected error occurred';
      conn.write(JSON.stringify([id, { message }]));
    }
  });

  conn.on('close', async () => {
    connCnt -= 1;
    log(`close. connCnt: ${connCnt}`);
    if (connCnt <= 0) {
      await log('no connection. close server');
      server.close();
    }
  });
};

main();
