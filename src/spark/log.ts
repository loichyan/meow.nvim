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
      const msg = string.format(fmt, ...args);
      function do_log(this: void) {
        vim.notify(msg, lv);
      }
      if (!vim.in_fast_event()) {
        do_log();
      } else {
        vim.schedule(() => {
          do_log();
        });
      }
    }
  };
}

export const debug = factory("DEBUG");
export const info = factory("INFO");
export const warn = factory("WARN");
export const error = factory("ERROR");
