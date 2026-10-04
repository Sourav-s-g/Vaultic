import { describe, expect, it } from "vitest";
import { categoryDeleteRpcArgs } from "./category-rpc";

describe("category deletion RPC arguments", () => {
  it("uses the applied parameter name and preserves stored category casing", () => {
    expect(categoryDeleteRpcArgs("fOoD")).toEqual({
      p_category_name: "fOoD",
    });
  });
});
