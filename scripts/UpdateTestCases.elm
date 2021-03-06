module UpdateTestCases exposing (main)

import Common
import Script exposing (Script)
import Script.Directory as Directory
import Script.File as File


script : Script.Init -> Script String ()
script { userPrivileges, workingDirectory } =
    let
        portabilityTestingDirectory =
            Directory.in_ workingDirectory "portability-testing"

        generateTestCases order =
            let
                outputFile =
                    File.in_ portabilityTestingDirectory
                        ("test_cases_" ++ String.fromInt order ++ ".txt")
            in
            Script.executeWith userPrivileges
                { workingDirectory = workingDirectory
                , command = "pict.exe"
                , arguments = [ "test_model.txt", "/o:" ++ String.fromInt order ]
                }
                |> Script.thenWith (\output -> File.writeTo outputFile output)
    in
    Script.do
        [ generateTestCases 2
        , generateTestCases 3
        ]


main : Script.Program
main =
    Common.program script
