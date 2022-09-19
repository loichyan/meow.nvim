import { Spec, SpecState } from "./shared";
import { merge_sort } from "./utils";

export function resolve_after(
  this: void,
  specs: Spec[]
): Lua.MultiReturn<[Spec[], undefined] | [undefined, string]> {
  interface Node {
    [1]: Spec;
    visited: boolean;
    resolved: boolean;
  }

  const nodes = new LuaMap<string, Node>();
  for (const [_, spec] of ipairs(specs)) {
    nodes.set(spec[1], {
      [1]: spec,
      visited: false,
      resolved: false,
    });
  }

  const resolved: Spec[] = [];

  function visit(
    this: void,
    spec: Spec
  ): Lua.MultiReturn<[SpecState, undefined] | [undefined, string]> {
    const name = spec[1];
    const node = nodes.get(name)!;
    // Reference to a resolved node, skip.
    if (node.resolved) {
      return $multi(spec.__state, undefined);
    }
    // If a node is visited twice, there's a cycle.
    if (node.visited) {
      return $multi(
        undefined,
        string.format("circular 'after' reference in '%s'", name)
      );
    }
    node.visited = true;
    let to_load = true;
    for (const [_, ref_name] of ipairs(spec.after)) {
      const ref_node = nodes.get(ref_name);
      if (ref_node == undefined) {
        return $multi(
          undefined,
          string.format(
            "undefined 'after' reference '%s' in '%s'",
            ref_name,
            name
          )
        );
      }
      const [state, err] = visit(ref_node[1]);
      if (state == undefined) {
        return $multi(undefined, err);
      } else if (
        state != "LOAD" &&
        state != "AFTER_LOAD" &&
        state != "LOADED"
      ) {
        to_load = false;
      }
    }
    if (!to_load) {
      spec.__state = "NONE";
    }
    node.resolved = true;
    table.insert(resolved, spec);
    return $multi(spec.__state, undefined);
  }

  for (const [_, spec] of ipairs(specs)) {
    const [state, err] = visit(spec);
    if (state == undefined) {
      return $multi(undefined, err);
    }
  }

  return $multi(resolved, undefined);
}

export function resolve(
  this: void,
  specs: Spec[]
): Lua.MultiReturn<[Spec[], undefined] | [undefined, string]> {
  table.sort(specs, (a, b) => a[1] < b[1]);
  specs = merge_sort(specs, (a, b) => a.priority - b.priority);
  return resolve_after(specs);
}
