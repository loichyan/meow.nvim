import { Config, CONFIG, PLUGINS, Spec } from "./spark/shared";
import * as sys from "./spark/sys";
import { deep_merge, join_path } from "./spark/utils";
import * as log from "./spark/log";
import { new_spec, validate } from "./spark/spec";
import { resolve } from "./spark/sequence";
import { Job } from "./spark/job";

function plug_path(this: void, is_start: boolean, name: string): string {
  let dir = "opt";
  if (is_start) {
    dir = "start";
  }
  return join_path(CONFIG.root, dir, name);
}

function local_plugin(this: void): LuaMap<string, boolean> {
  const plugins: LuaTable<string, boolean> = {} as any;
  for (const [name] of sys.scandir(plug_path(true, ""))) {
    plugins.set(name, true);
  }
  for (const [name] of sys.scandir(plug_path(false, ""))) {
    plugins.set(name, false);
  }
  return plugins;
}

export function setup(this: void, config?: DeepParitial<Config>) {
  deep_merge("force", CONFIG, config ?? {});
  const installed = local_plugin();
  const plugins: Spec[] = [];
  CONFIG[1]((orig) => {
    const [spec, err] = validate(orig);
    if (spec == undefined) {
      log.error(err);
      return;
    }
    const name = spec[1];
    if (spec.__state == "NONE") {
      // Figure out the initial state.
      const is_start = installed.get(name);
      installed.delete(name);
      if (is_start == undefined) {
        spec.__state = "CLONE";
      } else if (is_start) {
        spec.__state = "POST_LOAD";
      } else if (!spec.disable) {
        spec.__state = "LOAD";
      } else if (is_start != spec.start) {
        spec.__state = "MOVE";
      }
      // Cache plugin path.
      spec.__path = plug_path(spec.start, name);
    }

    table.insert(plugins, spec);
  });
  // Mark unused plugins to remove.
  for (const [name, start] of installed) {
    const spec = new_spec({ [1]: name, start });
    spec.__state = "REMOVE";
    table.insert(plugins, spec);
    spec.__path = plug_path(spec.start, name);
  }
  // Resolve load sequence.
  const [resolved, msg] = resolve(plugins);
  if (resolved == undefined) {
    log.error(msg);
    return;
  }

  for (const [_, v] of ipairs(resolved)) {
    table.insert(PLUGINS, v);
  }
}

export function plugins(this: void): Spec[] {
  return PLUGINS;
}

function post_update(this: void, spec: Spec) {
  const run = spec.run;
  if (run != undefined) {
    log.debug("post-update %s", spec[1]);
    if (type(run) == "function") {
      (run as Lua.MkFn<() => void>)();
    } else {
      Job.new({ cmd: run as string[], cwd: spec.__path }).run();
    }
  }
}

export function install(this: void) {
  for (const [_, spec] of ipairs(PLUGINS)) {
    const name = spec[1];
    if (spec.__state == "CLONE") {
      log.debug("install:clone %s", name);
      const [code] = Job.new({
        cmd: [
          "git",
          "clone",
          spec.from,
          spec.__path,
          "--depth",
          "1",
          "--progress",
        ],
      }).run();
      if (code == 0) {
        spec.__state = "LOAD";
        post_update(spec);
      }
    } else if (spec.__state == "MOVE") {
      log.debug("install:move %s", name);
      sys.rename(plug_path(!spec.start, name), spec.__path);
      spec.__state = "LOAD";
      break;
    }
  }
}

export function load(this: void) {
  for (const [_, spec] of ipairs(PLUGINS)) {
    const name = spec[1];
    if (spec.__state == "LOAD") {
      log.debug("load %s", name);
      vim.cmd("packadd " + name);
      spec.__state = "POST_LOAD";
    }
  }
}

export function post_load(this: void) {
  const cfg_post_load = CONFIG.post_load;
  for (const [_, spec] of ipairs(PLUGINS)) {
    const name = spec[1];
    if (spec.__state == "POST_LOAD") {
      const setup = spec.setup;
      if (setup != undefined) {
        log.debug("post-load:setup %s", name);
        setup();
      }
      if (cfg_post_load != undefined) {
        log.debug("post-load:config %s", name);
        cfg_post_load(spec);
      }
    }
  }
}

export function clean(this: void) {
  for (const [_, spec] of ipairs(PLUGINS)) {
    if (spec.__state == "REMOVE") {
      const name = spec[1];
      log.debug("remove %s", name);
      if (sys.remove(spec.__path)) {
        spec.__state = "NONE";
      }
    }
  }
}
