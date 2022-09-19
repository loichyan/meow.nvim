export declare function join_path(this: void, ...paths: string[]): string;
export declare function deep_merge<Behavior extends "force" | "keep", T1 extends Tbl, Rest extends Tbl[]>(this: void, behavior: Behavior, t1: T1, ...rest: Rest): MergeTbls<T1, Rest, Behavior extends "force" ? true : false>;
export declare function merge_sort<T>(this: void, list: T[], cmp: Lua.MkFn<(a: T, b: T) => number>): T[];
