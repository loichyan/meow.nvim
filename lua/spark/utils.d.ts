export declare function join_path(this: void, ...paths: string[]): string;
export declare function deep_merge<Force extends boolean, T1 extends Tbl, Rest extends Tbl[]>(this: void, force: Force, t1: T1, ...rest: Rest): MergeTbls<T1, Rest, Force>;
export declare function merge_sort<T>(this: void, list: T[], cmp: Lua.MkFn<(a: T, b: T) => number>): T[];
