export declare function join_path(this: void, ...paths: string[]): string;
declare type NonOptionalKeys<T> = {
    [K in keyof T]-?: never;
};
declare type DoMergeVal<V1, V2, Force> = Force extends true ? V2 : V1 extends undefined ? V2 : V1;
declare type MergeVal<V1, V2, Force> = V1 extends IsTbl<V1> ? V2 extends IsTbl<V2> ? Merge2T<V1, V2, Force> : DoMergeVal<V1, V2, Force> : DoMergeVal<V1, V2, Force>;
declare type Merge2T<T1, T2, Force> = {
    [K in keyof NonOptionalKeys<T1>]: K extends keyof T2 ? MergeVal<T1[K], T2[K], Force> : T1[K];
} & {
    [K in keyof NonOptionalKeys<T2> as K extends keyof T1 ? never : K]: T2[K];
};
declare type MergeTbls<Tbl1, Rest, Force> = Rest extends [infer Head, ...infer Tail] ? MergeTbls<Merge2T<Tbl1, Head, Force>, Tail, Force> : Tbl1;
export declare function deep_merge<Force extends boolean, T1 extends Tbl, Rest extends Tbl[]>(this: void, force: Force, t1: T1, ...rest: Rest): MergeTbls<T1, Rest, Force>;
export declare function merge_sort<T>(this: void, list: T[], cmp: Lua.MkFn<(a: T, b: T) => number>): T[];
export {};
