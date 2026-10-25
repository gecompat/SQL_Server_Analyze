using System;
using System.IO;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using Microsoft.SqlServer.Dts.Runtime;

// Eigene SDK-Autorschaft ohne Datenbank-, Datei- oder Netzwerkzugriffe im Paket.
// Der Fehlerfall startet ausschließlich cmd.exe /d /c exit 1 im Windows-Gast.
internal static class CreateScopeProject
{
    static List<object> objects = new List<object>();
    static void Record(string entry, DtsContainer item, string role)
    {
        string path = (string)item.GetType().GetMethod("GetPackagePath").Invoke(item, new object[0]);
        objects.Add(new { entry = entry, guid = Guid.Parse(item.ID).ToString("D"), path = path, name = item.Name, role = role });
    }
    static TaskHost Call(Executables executables, string name, string target, string entry)
    {
        var task = (TaskHost)executables.Add("Microsoft.ExecutePackageTask");
        task.Name = name;
        task.Properties["UseProjectReference"].SetValue(task, true);
        task.Properties["PackageName"].SetValue(task, target);
        Record(entry, task, "CALL");
        return task;
    }
    static void Handler(DtsContainer owner, DtsEventHandlers handlers, string eventName, string entry)
    {
        var handler = (DtsEventHandler)handlers.Add(eventName);
        Record(entry, handler, eventName);
        var body = (Sequence)handler.Executables.Add("STOCK:SEQUENCE");
        body.Name = "SyntheticHandlerBody";
        Record(entry, body, "HANDLER_BODY");
    }
    static int Main(string[] args)
    {
        if (args.Length < 2 || args[0].Length > 100 || args[1] != "SQLServer2025") return 2;
        try
        {
            using (var project = Project.CreateProject())
            {
                project.Name = args[0]; project.TargetServerVersion = DTSTargetServerVersion.SQLServer2025;
                project.ProtectionLevel = DTSProtectionLevel.DontSaveSensitive;
                var root = new Package { Name = "SyntheticRoot", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                var child = new Package { Name = "SyntheticChild", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                var grand = new Package { Name = "SyntheticGrandchild", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                var error = new Package { Name = "SyntheticError", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                foreach (var p in new[] { root, child, grand, error })
                {
                    string entry = p.Name + ".dtsx";
                    project.PackageItems.Add(p, entry); project.PackageItems[entry].EntryPoint = p == root || p == error;
                    Record(entry, p, "PACKAGE");
                }
                var sequence = (Sequence)root.Executables.Add("STOCK:SEQUENCE"); sequence.Name = "SyntheticSequence";
                Record("SyntheticRoot.dtsx", sequence, "SEQUENCE");
                Call(root.Executables, "SyntheticCallA", "SyntheticChild.dtsx", "SyntheticRoot.dtsx");
                Call(root.Executables, "SyntheticCallB", "SyntheticChild.dtsx", "SyntheticRoot.dtsx");
                root.Variables.Add("SyntheticIndex", false, "User", 0);
                var loop = (ForLoop)root.Executables.Add("STOCK:FORLOOP");loop.Name = "SyntheticLoop";
                loop.InitExpression = "@SyntheticIndex = 0";loop.EvalExpression = "@SyntheticIndex < 3";loop.AssignExpression = "@SyntheticIndex = @SyntheticIndex + 1";
                Record("SyntheticRoot.dtsx", loop, "LOOP");
                Call(loop.Executables, "SyntheticLoopCall", "SyntheticChild.dtsx", "SyntheticRoot.dtsx");
                Call(child.Executables, "SyntheticGrandCall", "SyntheticGrandchild.dtsx", "SyntheticChild.dtsx");
                var leaf = (Sequence)grand.Executables.Add("STOCK:SEQUENCE");leaf.Name = "SyntheticLeaf";Record("SyntheticGrandchild.dtsx", leaf, "LEAF");
                foreach (string eventName in new[] { "OnPreExecute", "OnPostExecute" })
                {
                    Handler(root, root.EventHandlers, eventName, "SyntheticRoot.dtsx");
                    Handler(child, child.EventHandlers, eventName, "SyntheticChild.dtsx");
                }
                Handler(error, error.EventHandlers, "OnError", "SyntheticError.dtsx");
                string processCreationName = null;
                foreach (TaskInfo info in new Application().TaskInfos)
                    if (info.CreationName != null && info.CreationName.StartsWith("Microsoft.SqlServer.Dts.Tasks.ExecuteProcess.ExecuteProcess,", StringComparison.Ordinal))
                    {
                        if (processCreationName != null) throw new InvalidOperationException("SYNTHETIC_PROCESS_TASK_AMBIGUOUS");
                        processCreationName = info.CreationName;
                    }
                if (processCreationName == null) throw new InvalidOperationException("SYNTHETIC_PROCESS_TASK_UNAVAILABLE");
                var fail = (TaskHost)error.Executables.Add(processCreationName); fail.Name = "SyntheticFailure";
                fail.Properties["Executable"].SetValue(fail, "cmd.exe");
                fail.Properties["Arguments"].SetValue(fail, "/d /c exit 1");
                fail.Properties["FailTaskIfReturnCodeIsNotSuccessValue"].SetValue(fail, true);
                fail.Properties["SuccessValue"].SetValue(fail, 0);Record("SyntheticError.dtsx", fail, "FAILURE");
                using (var memory = new MemoryStream())
                {
                    project.SaveTo(memory);if (memory.Length > 1048576) return 3;
                    Console.Write(new JavaScriptSerializer { MaxJsonLength = 4194304 }.Serialize(new {
                        ispacBase64 = Convert.ToBase64String(memory.ToArray()), objects = objects,
                        packageDtsId = Guid.Parse(root.ID).ToString("D"), packagePath = root.GetPackagePath(),
                        sequenceDtsId = Guid.Parse(sequence.ID).ToString("D"), sequencePath = sequence.GetPackagePath()
                    }));
                }
            }
            return 0;
        }
        catch (Exception) { Console.Error.Write("SYNTHETIC_SCOPE_SDK_AUTHOR_FAILED"); return 4; }
    }
}
