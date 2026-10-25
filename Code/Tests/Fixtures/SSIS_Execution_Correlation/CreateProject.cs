using System;
using System.IO;
using Microsoft.SqlServer.Dts.Runtime;

// Synthetische Testautorschaft im bestehenden Windows-SSIS-SDK, kein Produktparser.
// Base64 des eigenen ISPAC geht ausschließlich an den privaten Testprozess.
internal static class CreateProject
{
    private static int Main(string[] args)
    {
        if (args.Length != 2 || args[0].Length > 100 ||
            (args[1] != "SQLServer2019" && args[1] != "SQLServer2022" && args[1] != "SQLServer2025")) return 2;
        try
        {
            using (var project = Project.CreateProject())
            {
                project.Name = args[0];
                project.TargetServerVersion = (DTSTargetServerVersion)Enum.Parse(typeof(DTSTargetServerVersion), args[1]);
                project.ProtectionLevel = DTSProtectionLevel.DontSaveSensitive;
                var package = new Package { Name = "SyntheticCorrelationPackage", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                var sequence = (DtsContainer)package.Executables.Add("STOCK:SEQUENCE");
                sequence.Name = "SyntheticSequence";
                project.PackageItems.Add(package, "SyntheticRoot.dtsx");
                project.PackageItems["SyntheticRoot.dtsx"].EntryPoint = true;
                using (var memory = new MemoryStream())
                {
                    project.SaveTo(memory);
                    if (memory.Length > 1048576) return 3;
                    Console.Write(Convert.ToBase64String(memory.ToArray()));
                }
            }
            return 0;
        }
        catch (Exception) { Console.Error.Write("SYNTHETIC_SSIS_PROJECT_BUILD_FAILED"); return 4; }
    }
}
