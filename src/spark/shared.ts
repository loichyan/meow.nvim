import { join_path } from "./utils";

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR";

export type SpecState =
  | "NONE"
  | "MOVE"
  | "CLONE"
  | "REMOVE"
  | "LOAD"
  | "POST_LOAD"
  | "LOADED";

export interface Spec {
  [1]: string;
  from: string;
  start: boolean;
  disable: boolean;
  priority: number;
  setup?: Lua.MkFn<() => void>;
  after: string[];
  run?: Lua.MkFn<() => void> | string[];
  __state: SpecState;
  __path: string;
}

export const DEFAULT_SPEC: Spec = {
  [1]: "",
  from: "",
  start: false,
  disable: false,
  priority: 0,
  after: [],
  __state: "NONE",
  __path: "",
};

export interface Config {
  [1]: Lua.MkFn<(use: Lua.MkFn<(spec: Partial<Spec>) => void>) => void>;
  root: string;
  log: {
    level: LogLevel;
  };
  post_load?: Lua.MkFn<(spec: Spec) => void>;
}

export const CONFIG: Config = {
  [1]() {},
  root: join_path(vim.fn.stdpath("data"), "site/pack/spark"),
  log: {
    level: "WARN",
  },
};

export const PLUGINS: Spec[] = [];
