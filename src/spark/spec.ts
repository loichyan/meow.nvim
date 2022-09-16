import { DEFAULT_SPEC, Spec } from "./shared";
import { deep_merge } from "./utils";

export function new_spec(this: void, spec: DeepParitial<Spec>): Spec {
  return deep_merge(false, {} as any, spec as any, DEFAULT_SPEC as any) as any;
}

export function validate(
  this: void,
  orig: DeepParitial<Spec>
): LuaMultiReturn<[Spec, undefined] | [undefined, string]> {
  const spec2 = new_spec(orig);
  const name = orig[1];
  if (name == "") {
    return $multi(
      undefined,
      string.format("plugin name must be specified for '%s'", vim.inspect(orig))
    );
  }
  if (spec2.from == "") {
    return $multi(undefined, string.format("'from' is missed in '%s'", name));
  } else {
    spec2.from = "https://github.com/" + spec2.from;
  }
  if (spec2.start && spec2.disable) {
    return $multi(
      undefined,
      string.format("start plugin '%s' cannot be disabled", name)
    );
  }
  return $multi(spec2, undefined);
}

type A = {
  [Lua.brand]: string;
  a: { b: { c: string } };
};
