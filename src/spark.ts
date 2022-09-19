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
  deep_merge(true, CONFIG, config ?? {});
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
        spec.__state = "AFTER_LOAD";
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
  if (type(run) == "function") {
    (run as any)();
  } else {
    Job.new({ cmd: run as any, cwd: spec.__path }).run();
  }
}

export function install(this: void) {
  for (const [_, spec] of ipairs(PLUGINS)) {
    const name = spec[1];
    if (spec.__state == "CLONE") {
      log.debug("clone %s", name);
      const [code, signal, out, err] = Job.new({
        cmd: ["git", "clone", spec.from, spec.__path, "--depth", "1"],
      }).run();
      if (code == undefined) {
        return;
      }
      log.debug(
        "code %d, signal: %d, err: %s, out: %s",
        code,
        signal,
        out,
        err
      );
      if (code == 0) {
        spec.__state = "LOAD";
        post_update(spec);
      }
    } else if (spec.__state == "MOVE") {
      log.debug("move %s", name);
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
      spec.__state = "AFTER_LOAD";
    }
    if (spec.__state == "AFTER_LOAD") {
      log.debug("after load %s", name);
      spec.setup();
      CONFIG.after_load(spec);
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
