using System;
using System.IO;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using DataType = Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;

// SDK-Autorschaft ist die unabhängige Referenz für synthetische Pipelinebelege.
// Die Quelle liest ausschließlich fünf konstante Zeilen der eigenen Labinstanz;
// Row Count verändert nur eine eigene Paketvariable. Keine Nutzdatenexporte.
internal static class CreatePipelineProject
{
    static List<object> objects = new List<object>();
    static List<object> pipelines = new List<object>();
    static void Record(string entry, DtsContainer item, string role)
    {
        objects.Add(new { entry = entry, guid = Guid.Parse(item.ID).ToString("D"),
            path = (string)item.GetType().GetMethod("GetPackagePath").Invoke(item, new object[0]), name = item.Name, role = role });
    }
    static void Flow(Package package, Executables executables, string name, string target, bool fail = false, bool delay = false)
    {
        string entry = package.Name + ".dtsx";
        var connection = package.Connections.Add("DTS.ConnectionManagerOleDb.9"); connection.Name = "SyntheticConnection" + name;
        var settings = new System.Data.OleDb.OleDbConnectionStringBuilder();settings.Provider = "MSOLEDBSQL19";settings.DataSource = target;
        settings["Initial Catalog"] = "master";settings["Integrated Security"] = "SSPI";settings["Use Encryption for Data"] = true;settings["Trust Server Certificate"] = true;
        connection.ConnectionString = settings.ConnectionString;
        var host = (TaskHost)executables.Add("SSIS.Pipeline.9"); host.Name = name;host.LocaleID=1033;
        Record(entry, host, "PIPELINE");
        var pipe = (MainPipe)host.InnerObject;
        var source = pipe.ComponentMetaDataCollection.New(); source.ComponentClassID = "Microsoft.OLEDBSource";
        var sourceDesign = source.Instantiate(); sourceDesign.ProvideComponentProperties(); source.Name = "SyntheticSource";
        source.ValidateExternalMetadata = false;
        sourceDesign.SetComponentProperty("AccessMode", 2);
        sourceDesign.SetComponentProperty("SqlCommand", (delay ? "WAITFOR DELAY '00:00:20';" : "") + (fail ? "SET LANGUAGE us_english;SELECT CONVERT(int,N'SyntheticInvalid') AS SyntheticValue" : "SELECT CONVERT(int,v.n) AS SyntheticValue FROM (VALUES(1),(2),(3),(4),(5)) AS v(n)"));
        source.RuntimeConnectionCollection[0].ConnectionManagerID = connection.ID;
        source.RuntimeConnectionCollection[0].ConnectionManager = DtsConvert.GetExtendedInterface(connection);
        var output = source.OutputCollection[0];
        var column = output.OutputColumnCollection.New(); column.Name = "SyntheticValue"; column.SetDataTypeProperties(DataType.DT_I4, 0, 0, 0, 0);
        column.ErrorRowDisposition = DTSRowDisposition.RD_FailComponent;
        column.TruncationRowDisposition = DTSRowDisposition.RD_FailComponent;
        var external = output.ExternalMetadataColumnCollection.New(); external.Name = column.Name; external.DataType = DataType.DT_I4;
        column.ExternalMetadataColumnID = external.ID;
        var errorColumn = source.OutputCollection[1].OutputColumnCollection.New();
        errorColumn.Name = column.Name; errorColumn.SetDataTypeProperties(DataType.DT_I4, 0, 0, 0, 0);
        var branch = pipe.ComponentMetaDataCollection.New();branch.ComponentClassID = "Microsoft.Multicast";
        var branchDesign = branch.Instantiate();branchDesign.ProvideComponentProperties();branch.Name = "SyntheticBrancher";
        var firstPath = pipe.PathCollection.New();firstPath.AttachPathAndPropagateNotifications(output,branch.InputCollection[0]);firstPath.Name = "SyntheticInputTransfer";
        while (branch.OutputCollection.Count < 2) branch.OutputCollection.New();
        var componentOracle = new List<object>();var pathOracle = new List<object>();
        componentOracle.Add(new { name = source.Name, id = source.ID, reference = source.IdentificationString });
        componentOracle.Add(new { name = branch.Name, id = branch.ID, reference = branch.IdentificationString });
        pathOracle.Add(new { id = firstPath.ID, name = firstPath.Name, reference = firstPath.IdentificationString, source = source.Name, destination = branch.Name, rows = 5 });
        for (int index = 0; index < 2; index++)
        {
            var branchOutput = branch.OutputCollection[index];branchOutput.Name = "SyntheticBranch" + index;branchOutput.SynchronousInputID = branch.InputCollection[0].ID;
            string variable = "SyntheticCount" + name + index;package.Variables.Add(variable,false,"User",0);
            var counter = pipe.ComponentMetaDataCollection.New();counter.ComponentClassID = "Microsoft.RowCount";
            var counterDesign = counter.Instantiate();counterDesign.ProvideComponentProperties();counter.Name = "SyntheticCounter" + index;
            counterDesign.SetComponentProperty("VariableName","User::" + variable);
            var path = pipe.PathCollection.New();path.AttachPathAndPropagateNotifications(branchOutput,counter.InputCollection[0]);path.Name = "SyntheticTransfer" + index;
            componentOracle.Add(new { name = counter.Name, id = counter.ID, reference = counter.IdentificationString });
            pathOracle.Add(new { id = path.ID, name = path.Name, reference = path.IdentificationString, source = branch.Name, destination = counter.Name, rows = 5 });
        }
        // Multicast ergänzt beim Verbinden weitere Ausgänge; nur die beiden verwendeten bleiben.
        for (int index = branch.OutputCollection.Count - 1; index >= 2; index--)
            branch.OutputCollection.RemoveObjectByID(branch.OutputCollection[index].ID);
        if (branch.OutputCollection.Count != 2) throw new InvalidOperationException("SYNTHETIC_BRANCH_OUTPUT_COUNT");
        pipelines.Add(new { entry = entry, flowGuid = Guid.Parse(host.ID).ToString("D"), flowName = name, components = componentOracle, paths = pathOracle });
    }

    static void Call(Executables executables, string name, string entry)
    {
        var task = (TaskHost)executables.Add("SSIS.ExecutePackageTask.9"); task.Name = name;task.LocaleID=1033;
        task.Properties["UseProjectReference"].SetValue(task, true);task.Properties["PackageName"].SetValue(task,"SyntheticChild.dtsx");Record(entry, task, "CALL");
    }
    static int Main(string[] args)
    {
        if (args.Length < 2 || args[1] != "SQLServer2025") return 2;
        try
        {
            string target = args.Length > 2 && args[2] != "--oracle" ? args[2] : "localhost";
            using (var project = Project.CreateProject())
            {
                project.Name = args[0];project.TargetServerVersion = DTSTargetServerVersion.SQLServer2025;project.ProtectionLevel = DTSProtectionLevel.DontSaveSensitive;
                var root = new Package { Name = "SyntheticRoot", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive, LocaleID = 1033 };
                var child = new Package { Name = "SyntheticChild", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive, LocaleID = 1033 };
                root.CreationDate = new DateTime(2026, 1, 1, 10, 0, 0);child.CreationDate = root.CreationDate;
                project.PackageItems.Add(root,"SyntheticRoot.dtsx");project.PackageItems["SyntheticRoot.dtsx"].EntryPoint = true;
                project.PackageItems.Add(child,"SyntheticChild.dtsx");Record("SyntheticRoot.dtsx",root,"PACKAGE");Record("SyntheticChild.dtsx",child,"PACKAGE");
                Flow(root,root.Executables,"SyntheticFlowA",target);Flow(root,root.Executables,"SyntheticFlowB",target);
                Flow(child,child.Executables,"SyntheticFlowChild",target);
                Call(root.Executables,"SyntheticCallA","SyntheticRoot.dtsx");Call(root.Executables,"SyntheticCallB","SyntheticRoot.dtsx");
                root.Variables.Add("SyntheticIndex",false,"User",0);
                var loop = (ForLoop)root.Executables.Add("STOCK:FORLOOP");loop.Name = "SyntheticLoop";loop.LocaleID=1033;loop.InitExpression="@SyntheticIndex = 0";loop.EvalExpression="@SyntheticIndex < 2";loop.AssignExpression="@SyntheticIndex = @SyntheticIndex + 1";Record("SyntheticRoot.dtsx",loop,"LOOP");
                Call(loop.Executables,"SyntheticLoopCall","SyntheticRoot.dtsx");
                var error = new Package { Name = "SyntheticError", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive, LocaleID = 1033, CreationDate = root.CreationDate };
                var abort = new Package { Name = "SyntheticAbort", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive, LocaleID = 1033, CreationDate = root.CreationDate };
                project.PackageItems.Add(error,"SyntheticError.dtsx");project.PackageItems["SyntheticError.dtsx"].EntryPoint = true;Record("SyntheticError.dtsx",error,"PACKAGE");
                project.PackageItems.Add(abort,"SyntheticAbort.dtsx");project.PackageItems["SyntheticAbort.dtsx"].EntryPoint = true;Record("SyntheticAbort.dtsx",abort,"PACKAGE");
                Flow(error,error.Executables,"SyntheticFlowError",target,true,false);Flow(abort,abort.Executables,"SyntheticFlowAbort",target,false,true);
                using (var memory = new MemoryStream())
                {
                    project.SaveTo(memory);if(memory.Length>1048576)return 3;
                    Console.Write(new JavaScriptSerializer {MaxJsonLength=4194304}.Serialize(new {ispacBase64=Convert.ToBase64String(memory.ToArray()),objects=objects,pipelines=pipelines}));
                }
            }
            return 0;
        }
        catch(Exception) {Console.Error.Write("SYNTHETIC_PIPELINE_SDK_AUTHOR_FAILED");return 4;}
    }
}
