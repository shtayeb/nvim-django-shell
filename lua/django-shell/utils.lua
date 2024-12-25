local utils = {}

utils.pprint_queryset = function(shell_output)
   local pprinted_res = {}

   for _, value in pairs(shell_output) do
      local x, y = string.find(value, "<QuerySet ")

      if x and y then
         table.insert(pprinted_res, string.sub(value, 1, y + 2))

         local splited_qset_ob = vim.split(string.sub(value, y + 2), ",")
         for _, qset_obj in pairs(splited_qset_ob) do
            table.insert(pprinted_res, "    " .. vim.trim(qset_obj))
         end
      else
         table.insert(pprinted_res, value)
      end
   end

   return pprinted_res
end

utils.iswin = vim.loop.os_uname().sysname == "Windows_NT"

utils.cwd = vim.fn.getcwd()

utils.default_imports = {
   "from django.db.models import Avg, Case, Count, F, Max, Min, Prefetch, Q, Sum, When",
   "from django.conf import settings",
   "from django.urls import reverse",
   "from django.core.cache import cache",
   "from django.db import transaction",
   "from django.db.models import Exists, OuterRef, Subquery",
}

utils.find_python_path = function()
   local py_path = utils.cwd .. "/.venv/bin/python"

   if utils.iswin then
      py_path = utils.cwd .. "/.venv/Scripts/python"
   end

   return py_path
end

utils.find_manage_py = function()
   -- Check if manage.py exists in the current directory
   local manage_py_in_cwd = utils.cwd .. "/manage.py"
   if vim.fn.filereadable(manage_py_in_cwd) == 1 then
      return manage_py_in_cwd
   end

   -- Check for manage.py one level down
   local subdirs = vim.fn.glob(utils.cwd .. "/*", true, true) -- List all files and directories in cwd
   for _, subdir in ipairs(subdirs) do
      if vim.fn.isdirectory(subdir) == 1 then
         local manage_py_in_subdir = subdir .. "/manage.py"
         if vim.fn.filereadable(manage_py_in_subdir) == 1 then
            return manage_py_in_subdir
         end
      end
   end

   return nil
end

return utils
