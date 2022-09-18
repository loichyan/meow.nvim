export function join_path(this: void, ...paths: string[]): string {
  return table.concat(paths, "/");
}

type NonOptionalKeys<T> = {
  [K in keyof T]-?: never;
};

type DoMergeVal<V1, V2, Force> = Force extends true
  ? V2
  : V1 extends undefined
  ? V2
  : V1;

type MergeVal<V1, V2, Force> = V1 extends IsTbl<V1>
  ? V2 extends IsTbl<V2>
    ? Merge2T<V1, V2, Force>
    : DoMergeVal<V1, V2, Force>
  : DoMergeVal<V1, V2, Force>;

type Merge2T<T1, T2, Force> = {
  [K in keyof NonOptionalKeys<T1>]: K extends keyof T2
    ? MergeVal<T1[K], T2[K], Force>
    : T1[K];
} & {
  [K in keyof NonOptionalKeys<T2> as K extends keyof T1 ? never : K]: T2[K];
};

type MergeTbls<Tbl1, Rest, Force> = Rest extends [infer Head, ...infer Tail]
  ? MergeTbls<Merge2T<Tbl1, Head, Force>, Tail, Force>
  : Tbl1;

export function deep_merge<
  Force extends boolean,
  T1 extends Tbl,
  Rest extends Tbl[]
>(this: void, force: Force, t1: T1, ...rest: Rest): MergeTbls<T1, Rest, Force> {
  const tbl1 = t1 as any as LuaTable<string | number>;
  for (const [_, tbl2] of ipairs(rest as any as LuaTable<string | number>[])) {
    for (const [k, v2] of pairs(tbl2)) {
      const v1 = tbl1.get(k);
      if (type(v1) == "table" && type(v2) == "table") {
        deep_merge(force, v1, v2);
      } else if (force) {
        tbl1.set(k, v2);
      } else if (!v1) {
        tbl1.set(k, v2);
      }
    }
  }
  return tbl1 as any;
}

export function merge_sort<T>(
  this: void,
  list: T[],
  cmp: Lua.MkFn<(a: T, b: T) => number>
): T[] {
  const len = list.length;
  let tmp: T[] = [];
  for (let seg = 1; seg < len; seg += seg) {
    for (let start = 0; start < len; start += seg * 2) {
      let start1 = start,
        end1 = math.min(start + seg, len),
        start2 = end1,
        end2 = math.min(start + seg * 2, len);
      while (start1 < end1 && start2 < end2) {
        table.insert(
          tmp,
          cmp(list[start1], list[start2]) <= 0 ? list[start1++] : list[start2++]
        );
      }
      while (start1 < end1) table.insert(tmp, list[start1++]);
      while (start2 < end2) table.insert(tmp, list[start2++]);
    }
    list = tmp;
    tmp = [];
  }
  return list;
}
