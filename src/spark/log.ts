import { CONFIG, LogLevel } from "./shared";

function factory(this: void, level: LogLevel) {
  return function (this: void, fmt: string, ...args: any[]) {
    if (level >= CONFIG.log.level) {
      vim.notify(string.format(fmt, ...args), level);
    }
  };
}

export const debug = factory(LogLevel.DEBUG);
export const info = factory(LogLevel.INFO);
export const warn = factory(LogLevel.WARN);
export const error = factory(LogLevel.ERROR);
