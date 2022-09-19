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
  wait(this: Job, timeout?: number): void;
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

function new_pipe(
  this: void,
  cb: Lua.MkFn<(data: string) => void>
): uv.pipe_t | undefined {
  const [pipe, err] = uv.new_pipe();
  if (pipe == undefined) {
    log.error(err);
    return;
  }
  uv.read_start(pipe, (err, ok) => {
    if (err != undefined) {
      log.error(err);
    } else {
      cb(ok);
    }
  });
  return pipe;
}

export const Job: JobConstructor = {
  new(opts) {
    return {
      __opts: opts,
      __exited: false,
      spawn(opts = {}) {
        const gOpts = this.__opts;
        log.debug("run '%s'", table.concat(gOpts.cmd, " "));
        const [ok, err] = uv.spawn(
          table.remove(gOpts.cmd, 1)!,
          {
            args: gOpts.cmd,
            cwd: gOpts.cwd,
            stdio: [
              undefined as any,
              !opts.onstdout ? undefined : new_pipe(opts.onstdout),
              !opts.onstderr ? undefined : new_pipe(opts.onstderr),
            ],
          },
          (code, signal) => {
            this.__exited = true;
            if (opts.onexit != undefined) {
              opts.onexit(code, signal);
            }
          }
        );
        if (ok == undefined) {
          log.error(err);
          this.__exited = true;
        }
        return this;
      },
      wait(timeout = 5000) {
        vim.wait(
          timeout,
          () => {
            return this.__exited;
          },
          10
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
            stdout += data;
          },
          onstderr(data) {
            stderr += data;
          },
        });
        this.wait(timeout);
        if (code == undefined || signal == undefined) {
          return $multi() as any;
        }
        return $multi(code, signal, stdout, stderr);
      },
    };
  },
};
