import { CONFIG, LogLevel } from "./shared";

const levels = vim.log.levels;

function level2vim(this: void, level: LogLevel): vim.log.levels {
  switch (level) {
    case "DEBUG":
      return levels.DEBUG;
    case "INFO":
      return levels.INFO;
    case "WARN":
      return levels.WARN;
    case "ERROR":
      return levels.ERROR;
  }
}

function factory(this: void, level: LogLevel) {
  const lv = level2vim(level);
  return function (this: void, fmt: string, ...args: any[]) {
    if (lv >= level2vim(CONFIG.log.level)) {
      vim.notify(string.format(fmt, ...args), lv);
    }
  };
}

export const debug = factory("DEBUG");
export const info = factory("INFO");
export const warn = factory("WARN");
export const error = factory("ERROR");
