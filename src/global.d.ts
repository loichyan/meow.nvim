/// <reference types="lua-types/jit" />

declare type Tbl = { [k: number | string]: any };

declare type IsTbl<T> = T extends any[]
  ? never
  : T extends Function
  ? never
  : T extends Tbl
  ? T
  : never;

declare type DeepParitial<T> = {
  [K in keyof T as K extends symbol ? never : K]?: T[K] extends IsTbl<T[K]>
    ? DeepParitial<T[K]>
    : T[K];
} & {
  [K in keyof T as K extends symbol ? K : never]: T[K];
};

declare namespace Lua {
  type MkFn<F> = F extends (...args: infer A) => infer R
    ? (this: void, ...args: A) => R
    : never;

  type Iterator<TValue, TState = undefined> = MultiReturn<
    [(this: void, state: TState) => TValue | undefined, TState]
  >;

  type Iterable<TValue, TState = undefined> = globalThis.Iterable<TValue> &
    Iterator<TValue, TState> &
    LuaIterationExtension<"Iterable">;

  /**
   * When passing a tuple union, you must pad all variants with `undefined` to
   * the same length, because intersection tuple and a brand object lets the tuple become an array.
   * Maybe relates with https://github.com/microsoft/TypeScript/pull/46265.
   */
  type MultiReturn<T> = T extends unknown[] ? LuaMultiReturn<T> : never;

  const brand: unique symbol;
  type brand = typeof brand;
  type MkUserdata<B> = B extends { [K: symbol]: brand }
    ? { [brand]: B } & LuaUserdata
    : never;
}

declare namespace uv {
  type fail = [undefined, string];

  type result<T, E = fail> = Lua.MultiReturn<T | E>;

  type fn<A, R, E = fail> = A extends any[]
    ? Lua.MkFn<(...args: A) => result<R, E>>
    : never;

  type callback<T, E = string> = Lua.MkFn<
    (...args: [err: undefined, ok: T] | [err: E, ok: undefined]) => void
  >;

  type asyncfn<A, RSync, RAsync, E = string> = A extends unknown[]
    ? fn<A, [RSync, undefined]> &
        fn<[...args: A, cb: callback<RSync, E>], RAsync>
    : never;

  type fs_t = LuaUserdata & typeof __fs_t;
  const __fs_t: unique symbol;

  type fs_scandir = asyncfn<[path: string], fs_t, fs_t>;

  type fs_scandir_next = fn<[fs: fs_t], [string, fs_stat_type] | []>;

  interface fs_time {
    sec: number;
    nsec: number;
  }

  type fs_stat_type =
    | "file"
    | "directory"
    | "link"
    | "fifo"
    | "socket"
    | "char"
    | "block";

  interface fs_stat_obj {
    dev: number;
    mode: number;
    nlink: number;
    uid: number;
    gid: number;
    rdev: number;
    blksize: number;
    blocks: number;
    flags: number;
    gen: number;
    atime: fs_time;
    mtime: fs_time;
    ctime: fs_time;
    birthtime: fs_time;
    type: fs_stat_type;
  }

  type fs_stat = asyncfn<[path: string], fs_stat_obj, fs_t>;

  type fs_fstat = asyncfn<[fd: number], fs_stat_obj, fs_t>;

  type fs_lstat = fs_stat;

  type fs_rename = asyncfn<[path: string, newpath: string], boolean, fs_t>;

  type fs_unlink = asyncfn<[path: string], boolean, fs_t>;

  type fs_rmdir = asyncfn<[path: string], boolean, fs_t>;

  type stream_t = Lua.MkUserdata<{ [__stream_t]: Lua.brand }>;
  const __stream_t: unique symbol;

  type pipe_t = Lua.MkUserdata<{
    [__stream_t]: Lua.brand;
    [__pipe_t]: Lua.brand;
  }>;
  const __pipe_t: unique symbol;

  type new_pipe = fn<[ipc?: boolean], [pipe_t, undefined]>;

  type read_start = fn<
    [stream: stream_t, cb: callback<string>],
    [0, undefined]
  >;

  interface spawn_opts {
    args?: string[];
    stdio?: Partial<[pipe_t, pipe_t, pipe_t]>;
    env?: { [k: string]: string };
    cwd?: string;
    uid?: number;
    gid?: number;
    verbatim?: boolean;
    detached?: boolean;
    hide?: boolean;
  }

  type spawn = fn<
    [
      path: string,
      opts?: spawn_opts,
      onexit?: (code: number, signal: number) => void
    ],
    [0, undefined]
  >;
}

declare namespace vim {
  namespace log {
    enum levels {
      TRACE,
      DEBUG,
      INFO,
      WARN,
      ERROR,
    }
  }

  namespace fn {
    const stdpath: Lua.MkFn<(what: "data" | "config") => string>;
  }

  namespace loop {
    const fs_scandir: uv.fs_scandir;

    const fs_scandir_next: uv.fs_scandir_next;

    const fs_stat: uv.fs_stat;

    const fs_fstat: uv.fs_fstat;

    const fs_lstat: uv.fs_lstat;

    const fs_rename: uv.fs_rename;

    const fs_unlink: uv.fs_unlink;

    const fs_rmdir: uv.fs_rmdir;

    const new_pipe: uv.new_pipe;

    const read_start: uv.read_start;

    const spawn: uv.spawn;
  }

  const notify: Lua.MkFn<(msg: string, level?: vim.log.levels) => void>;

  const wait: Lua.MkFn<
    (timeout: number, cb?: Lua.MkFn<() => void>, interval?: number) => void
  >;

  const inspect: Lua.MkFn<(t: any) => string>;

  const cmd: Lua.MkFn<(s: string) => void>;
}
