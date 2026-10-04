export function categoryDeleteRpcArgs(storedCategoryName: string): {
  p_category_name: string;
} {
  return { p_category_name: storedCategoryName };
}
