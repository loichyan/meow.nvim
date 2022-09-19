import * as log from "./log";
const uv = vim.loop;

export interface SpawnOpts {
  onexit?: Lua.MkFn<(code: number, signal: number) => void>;
  onstdout?: Lua.MkFn<(data: string) => void>;
  onstderr?: Lua.MkFn<(data: string) => void>;
}

export interface JobOpts {
  cmd: string[];
  cwd?: string;
}

export interface Job {
  readonly __opts: JobOpts;
  __exited: boolean;
  spawn(this: Job, opts?: SpawnOpts): Job;
  wait(this: Job, timeout?: number): ReturnType<typeof vim.wait>;
  run(
    this: Job,
    timeout?: number
  ): Lua.MultiReturn<
    | [number, number, string, string]
    | [undefined, undefined, undefined, undefined]
  >;
}

interface JobConstructor {
  new: Lua.MkFn<(opts: JobOpts) => Job>;
}

function new_pipe(this: void): uv.pipe_t | undefined {
  const [pipe, err] = uv.new_pipe();
  if (pipe == undefined) {
    log.error(err);
    return;
  }
  return pipe;
}

function mk_pipe_reader(
  this: void,
  cb: (this: void, data: string) => void
): Parameters<uv.read_start>[1] {
  return (err, ok) => {
    if (err != undefined) {
      log.error(err);
    } else if (ok != undefined) {
      cb(ok);
    }
  };
}

export const Job: JobConstructor = {
  new(opts) {
    return {
      __opts: opts,
      __exited: false,
      spawn(opts = {}) {
        const gOpts = this.__opts;
        log.debug("run '%s'", table.concat(gOpts.cmd, " "));
        const stdout = opts.onstdout == undefined ? undefined : new_pipe();
        const stderr = opts.onstderr == undefined ? undefined : new_pipe();
        const [hd] = uv.spawn(
          table.remove(gOpts.cmd, 1)!,
          {
            args: gOpts.cmd,
            cwd: gOpts.cwd,
            stdio: [undefined as any, stdout, stderr],
          },
          (code, signal) => {
            this.__exited = true;
            uv.close(hd);
            if (opts.onexit != undefined) {
              opts.onexit(code, signal);
            }
          }
        );
        if (stdout != undefined && opts.onstdout != undefined) {
          uv.read_start(stdout, mk_pipe_reader(opts.onstdout));
        }
        if (stderr != undefined && opts.onstderr != undefined) {
          uv.read_start(stderr, mk_pipe_reader(opts.onstderr));
        }
        return this;
      },
      wait(timeout = 5000) {
        return vim.wait(
          timeout,
          () => {
            return this.__exited;
          },
          200
        );
      },
      run(timeout = 5000) {
        let stdout = "",
          stderr = "",
          code: number | undefined,
          signal: number | undefined;
        this.spawn({
          onexit(c, s) {
            code = c;
            signal = s;
          },
          onstdout(data) {
            stdout += data + "\n";
          },
          onstderr(data) {
            stderr += data + "\n";
          },
        });
        const [wait_ok, wait_code] = this.wait(timeout);
        if (!wait_ok) {
          if (wait_code == -1) {
            log.error("waiting is timeout");
          } else {
            log.error("waiting is interrupted");
          }
        }
        if (code == undefined || signal == undefined) {
          return $multi() as any;
        }
        return $multi(code, signal, stdout, stderr);
      },
    };
  },
};
