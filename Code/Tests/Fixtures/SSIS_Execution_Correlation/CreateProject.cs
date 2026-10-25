using System;
using System.IO;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Runtime.Enumerators.NodeList;

// Synthetische Testautorschaft im bestehenden Windows-SSIS-SDK, kein Produktparser.
// Base64 des eigenen ISPAC geht ausschließlich an den privaten Testprozess.
internal static class CreateProject
{
    private static int Main(string[] args)
    {
        bool iterations = args.Length == 4 && args[3] == "--iterations";
        if ((args.Length != 2 && args.Length != 3 && !iterations) || (args.Length >= 3 && args[2] != "--oracle") || args[0].Length > 100 ||
            (args[1] != "SQLServer2019" && args[1] != "SQLServer2022" && args[1] != "SQLServer2025")) return 2;
        try
        {
            using (var project = Project.CreateProject())
            {
                project.Name = args[0];
                project.TargetServerVersion = (DTSTargetServerVersion)Enum.Parse(typeof(DTSTargetServerVersion), args[1]);
                project.ProtectionLevel = DTSProtectionLevel.DontSaveSensitive;
                var package = new Package { Name = "SyntheticCorrelationPackage", ProtectionLevel = DTSProtectionLevel.DontSaveSensitive };
                var sequence = (Sequence)package.Executables.Add("STOCK:SEQUENCE");
                sequence.Name = "SyntheticSequence";
                ForLoop loop = null;
                ForEachLoop each = null;
                Sequence repeated = null, eachRepeated = null;
                if (iterations)
                {
                    package.Variables.Add("SyntheticIndex", false, "User", 0);
                    loop = (ForLoop)package.Executables.Add("STOCK:FORLOOP");
                    loop.Name = "SyntheticFor";
                    loop.InitExpression = "@SyntheticIndex = 0";
                    loop.EvalExpression = "@SyntheticIndex < 3";
                    loop.AssignExpression = "@SyntheticIndex = @SyntheticIndex + 1";
                    repeated = (Sequence)loop.Executables.Add("STOCK:SEQUENCE");
                    repeated.Name = "SyntheticRepeated";
                    each = (ForEachLoop)package.Executables.Add("STOCK:FOREACHLOOP");
                    each.Name = "SyntheticEach";
                    var enumerator = new Application().ForEachEnumeratorInfos["Foreach NodeList Enumerator"].CreateNew();
                    package.Variables.Add("SyntheticItem", false, "User", "");
                    var mapping = each.VariableMappings.Add();
                    mapping.VariableName = "User::SyntheticItem";
                    mapping.ValueIndex = 0;
                    // Zwei konstante XML-Knoten; weder Datei- noch SQL-Zugriff.
                    var nodes = (ForEachNodeListEnumerator)enumerator.InnerObject;
                    nodes.SourceDocumentType = SourceType.DirectInput;
                    nodes.SourceDocument = "<SyntheticItems><SyntheticItem>1</SyntheticItem><SyntheticItem>2</SyntheticItem></SyntheticItems>";
                    nodes.OuterXPathStringSourceType = SourceType.DirectInput;
                    nodes.OuterXPathString = "/SyntheticItems/SyntheticItem";
                    nodes.EnumerationType = EnumerationType.NodeText;
                    each.ForEachEnumerator = enumerator;
                    eachRepeated = (Sequence)each.Executables.Add("STOCK:SEQUENCE");
                    eachRepeated.Name = "SyntheticRepeated";
                }
                project.PackageItems.Add(package, "SyntheticRoot.dtsx");
                project.PackageItems["SyntheticRoot.dtsx"].EntryPoint = true;
                using (var memory = new MemoryStream())
                {
                    project.SaveTo(memory);
                    if (memory.Length > 1048576) return 3;
                    var archive = Convert.ToBase64String(memory.ToArray());
                    if (args.Length == 2) Console.Write(archive);
                    else
                    {
                        // Erwartungswerte stammen vom Autorobjekt des SDKs;
                        // weder Toolbelt-Ausgabe noch ein zweiter XML-Parser
                        // bestimmen das GUID-/Pfadoracle.
                        Console.Write("{\"ispacBase64\":\"" + archive +
                            "\",\"packageDtsId\":\"" + Guid.Parse(package.ID).ToString("D") +
                            "\",\"packagePath\":\"" + Escape(package.GetPackagePath()) +
                            "\",\"sequenceDtsId\":\"" + Guid.Parse(sequence.ID).ToString("D") +
                            "\",\"sequencePath\":\"" + Escape(sequence.GetPackagePath()) + "\"" +
                            (iterations ? ",\"forGuid\":\"" + Guid.Parse(loop.ID).ToString("D") +
                            "\",\"forPath\":\"" + Escape(loop.GetPackagePath()) +
                            "\",\"eachGuid\":\"" + Guid.Parse(each.ID).ToString("D") +
                            "\",\"eachPath\":\"" + Escape(each.GetPackagePath()) +
                            "\",\"repeatedGuid\":\"" + Guid.Parse(repeated.ID).ToString("D") +
                            "\",\"repeatedPath\":\"" + Escape(repeated.GetPackagePath()) +
                            "\",\"eachRepeatedGuid\":\"" + Guid.Parse(eachRepeated.ID).ToString("D") +
                            "\",\"eachRepeatedPath\":\"" + Escape(eachRepeated.GetPackagePath()) + "\"" : "") + "}");
                    }
                }
            }
            return 0;
        }
        catch (Exception) { Console.Error.Write("SYNTHETIC_SSIS_PROJECT_BUILD_FAILED"); return 4; }
    }

    private static string Escape(string value)
    {
        var slash = ((char)92).ToString();
        var quote = ((char)34).ToString();
        return value.Replace(slash, new string((char)92, 2)).Replace(quote, slash + quote);
    }
}
