import * as log from "./log";
import { join_path } from "./utils";
const uv = vim.loop;

export function scandir(
  this: void,
  path: string
): Lua.Iterable<Lua.MultiReturn<[string, uv.fs_stat_type]>, uv.fs_t> {
  const [fs, err] = uv.fs_scandir(path);
  if (fs == undefined) {
    log.error(err);
    return (() => {}) as any;
  }
  function iter(this: void, fs: uv.fs_t) {
    const [name, type] = uv.fs_scandir_next(fs);
    if (name == undefined) {
      if (type != undefined) {
        log.error(type);
      }
      return;
    }
    return $multi(name, type);
  }
  return $multi(iter, fs) as any;
}

export function remove(this: void, path: string): boolean {
  const [stat, err] = uv.fs_lstat(path);
  if (stat == undefined) {
    log.error(err);
    return false;
  }
  if (stat.type == "directory") {
    return remove_dir(path);
  }
  return remove_file(path);
}

export function remove_dir(this: void, path: string): boolean {
  for (const [name, type] of scandir(path)) {
    if (type == "directory") {
      if (!remove_dir(join_path(path, name))) {
        return false;
      }
    } else {
      if (!remove_file(join_path(path, name))) {
        return false;
      }
    }
  }
  const [ok, err] = uv.fs_rmdir(path);
  if (ok == undefined) {
    log.error(err!);
    return false;
  }
  return true;
}

export function remove_file(this: void, path: string): boolean {
  const [ok, err] = uv.fs_unlink(path);
  if (ok == undefined) {
    log.error(err!);
    return false;
  }
  return true;
}

export function rename(this: void, path: string, newpath: string): boolean {
  const [ok, err] = uv.fs_rename(path, newpath);
  if (ok == undefined) {
    log.error(err!);
    return false;
  }
  return true;
}

export function exists(this: void, path: string): uv.fs_stat_obj | undefined {
  const [stat] = uv.fs_lstat(path);
  if (stat == undefined) {
    return;
  }
  return stat;
}
