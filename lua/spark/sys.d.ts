export declare function scandir(this: void, path: string): Lua.Iterable<Lua.MultiReturn<[string, uv.fs_stat_type]>, uv.fs_t>;
export declare function remove(this: void, path: string): boolean;
export declare function remove_dir(this: void, path: string): boolean;
export declare function remove_file(this: void, path: string): boolean;
export declare function rename(this: void, path: string, newpath: string): boolean;
export declare function exists(this: void, path: string): uv.fs_stat_obj | undefined;
