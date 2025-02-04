local utils = {}

utils.default_imports = {
   "from django.db.models import Avg, Case, Count, F, Max, Min, Prefetch, Q, Sum, When",
   "from django.conf import settings",
   "from django.urls import reverse",
   "from django.core.cache import cache",
   "from django.db import transaction",
   "from django.db.models import Exists, OuterRef, Subquery",
}

utils.cwd = vim.fn.getcwd()
utils.iswin = vim.loop.os_uname().sysname == "Windows_NT"

utils.find_python_path = function()
   local common_venv_dirs = { ".venv", "venv", "env" }

   -- Find the virtual environment directory
   local venv_path = ""

   for _, dir in pairs(common_venv_dirs) do
      local dir_path = vim.fn.finddir(dir, utils.cwd .. ";")
      if dir_path ~= "" then
         venv_path = dir_path
         break
      end
   end

   -- Determine the python executable path
   local py_executable = utils.iswin and "python.exe" or "python"

   local py_path = vim.fn.findfile(py_executable, venv_path .. "/**1")

   if py_path == "" then
      vim.notify("No Python executable found in the virtual environment.", vim.log.levels.INFO)
   end

   return py_path
end

utils.find_manage_py = function()
   -- Check if manage.py exists in the current directory
   local manage_py = vim.fn.findfile("manage.py", "**2")

   if manage_py == "" then
      return nil
   end

   -- check if manage_py is readable -> 0|1
   if vim.fn.filereadable(manage_py) == 0 then
      -- file is not readable
      return nil
   end

   return manage_py
end

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

--
-- The project data
--
utils.config_file = vim.fn.stdpath("data") .. "/django_shell_projects.json"

utils.reset_project_data = function()
   local projects = {}
   local base_dir = utils.cwd

   local file = io.open(utils.config_file, "r")
   if not file then
      return
   end

   local content = file:read("*a")
   file:close()

   if content == "" then
      return
   end

   local ok, decoded_content = pcall(vim.fn.json_decode, content)
   if ok then
      projects = decoded_content
   end

   -- remove the project info
   projects[base_dir] = nil

   -- Save back to the file
   file = io.open(utils.config_file, "w")

   if file then
      file:write(vim.fn.json_encode(projects))
      file:close()

      vim.notify("Paths for project '" .. base_dir .. "' has been reset successfully.", vim.log.levels.INFO)
   else
      vim.notify("Failed to reset project paths.", vim.log.levels.ERROR)
   end
end

utils.save_project_paths = function(base_dir, python_path, manage_py_path)
   local projects = {}

   -- Load existing projects if the config file exists
   local file = io.open(utils.config_file, "r")

   if file then
      local content = file:read("*a")

      file:close()

      if content ~= "" then
         local ok, decoded_content = pcall(vim.fn.json_decode, content)
         if ok then
            projects = decoded_content
         end
      end
   end

   -- Update the project-specific paths
   projects[base_dir] = {
      python_path = python_path,
      manage_py_path = manage_py_path,
   }

   -- Save back to the file
   file = io.open(utils.config_file, "w")

   if file then
      file:write(vim.fn.json_encode(projects))
      file:close()

      vim.notify("Paths for project '" .. base_dir .. "' saved successfully.", vim.log.levels.INFO)
   else
      vim.notify("Failed to save project paths.", vim.log.levels.ERROR)
   end
end

utils.load_project_paths = function(base_dir)
   local file = io.open(utils.config_file, "r")

   if file then
      local content = file:read("*a")

      file:close()

      local ok, projects = pcall(vim.fn.json_decode, content)
      if not ok then
         projects = {}
      end

      if projects and projects[base_dir] then
         return projects[base_dir].python_path, projects[base_dir].manage_py_path
      end
   end

   return nil, nil
end

utils.ask_user_for_project_paths = function(base_dir)
   vim.notify("Configuration not found for project enter them manually " .. base_dir, vim.log.levels.INFO)

   local python_path = vim.fn.input("Enter the venv python path: ")
   local manage_py_path = vim.fn.input("Enter the path to manage.py file: ")

   if python_path == "" or vim.fn.filereadable(python_path) == 0 then
      -- file is not readable
      vim.notify("python is not readable", vim.log.levels.ERROR)

      return nil, nil
   end

   -- check if manage_py is readable -> 0|1
   if manage_py_path == "" or vim.fn.filereadable(manage_py_path) == 0 then
      -- file is not readable
      vim.notify("manage.py is not readable", vim.log.levels.ERROR)

      return nil, nil
   end

   utils.save_project_paths(base_dir, python_path, manage_py_path)

   return python_path, manage_py_path
end

utils.get_project_paths = function()
   local base_dir = utils.cwd

   -- Attempt to load paths for this project from file
   local loaded_python_path, loaded_manage_py_path = utils.load_project_paths(base_dir)
   if loaded_python_path or loaded_manage_py_path then
      return loaded_python_path, loaded_manage_py_path
   end

   -- not path in the config file -> auto discover them
   local python_path = utils.find_python_path()
   local manage_py_path = utils.find_manage_py()

   if not python_path or not manage_py_path then
      -- paths are not found, ask the user
      python_path, manage_py_path = utils.ask_user_for_project_paths(base_dir)
   else
      -- paths found from auto detect - save them
      utils.save_project_paths(base_dir, python_path, manage_py_path)
   end

   return python_path, manage_py_path
end

return utils
