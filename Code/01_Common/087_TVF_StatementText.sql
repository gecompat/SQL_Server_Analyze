USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_StatementText
Version      : 1.0.0
Stand        : 2026-07-16
Typ          : Inline Table-valued Function
Zweck        : Schneidet ein Statement aus einem übergebenen nvarchar(max)-Batch
               anhand der Request-Offsets aus und liefert elf transparente
               Offset-, Zeichen-, Zeilen-, Längen- und Textausgaben.
Parameter    : @BatchText, @StatementStartOffsetBytes und
               @StatementEndOffsetBytes sind Pflichtparameter ohne Defaults.
               Die Funktion parst kein SQL, liest keine DMVs und trifft keine
               Autoritätsentscheidung.
Offsetregeln : HasStatementOffsets folgt ausschließlich daraus, ob das
               Startargument angegeben (nicht NULL) ist. Intern wird ein
               NULL-Start zu 0; die öffentlichen Start- und Endoffsets bleiben
               dann NULL und HasStatementOffsets ist 0. NULL oder -1 am Ende
               bedeutet intern Batchende; öffentlich wird -1 ausgegeben,
               wenn HasStatementOffsets = 1. Sind beide Argumente NULL, wird
               der ganze Batch projiziert. Ein NULL-Start mit angegebenem Ende
               kann einen Teilausschnitt vom Batchanfang liefern.
Gültigkeit   : Text darf nicht NULL sein; beide normalisierten Offsets müssen
               nichtnegativ, gerade, Start <= Ende und <= DATALENGTH(Text)
               sein. Das Ende ist inklusiv; SUBSTRING erhält daher
               ((Ende - Start) / 2) + 1 Zeichen ab Start / 2 + 1 (1-basiert).
               Der Schnitt endet am Textende. Start = Batchbytes ist gültig
               und kann ein leeres Statement mit NULL-Endzeichen ergeben.
Ausgaben     : HasStatementOffsets, IsStatementOffsetValid,
               StatementStartOffsetBytes, StatementEndOffsetBytes,
               StatementStartCharacter, StatementEndCharacter,
               StatementStartLine, StatementEndLine,
               StatementCharacterCount, BatchCharacterCount und StatementText.
               Ungültiger Text oder ungültige Positionen ergeben NULL-Text;
               Flags und Offsets folgen jeweils den obigen Quellregeln und
               sind nicht pauschal alle NULL.
Zählung      : Byte-Längen stammen aus DATALENGTH; / 2 zählt UTF-16-Codeunits,
               keine Supplementary-Character-Codepoints. Zeilen zählen LF
               (NCHAR(10)); CR allein erhöht die Zeile nicht. LEN und
               SUBSTRING folgen der wirksamen Kollation. Für Surrogate wird
               keine allgemeine Behandlungsgarantie gegeben.
Beispiele    : Synthetische Aufrufe ohne Hostdaten:
               SELECT * FROM monitor.TVF_StatementText(N'SELECT 1;', NULL, NULL);
               SELECT * FROM monitor.TVF_StatementText(N'ABCDEF', 2, 5);
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_StatementText]
(
      @BatchText                  nvarchar(max)
    , @StatementStartOffsetBytes  int
    , @StatementEndOffsetBytes    int
)
RETURNS TABLE
AS
RETURN
(
    WITH [Normalized] AS
    (
        SELECT
              [BatchText] = @BatchText
            , [BatchLengthBytes] = DATALENGTH(@BatchText)
            , [HasOffsets] = CONVERT(bit, CASE WHEN @StatementStartOffsetBytes IS NULL THEN 0 ELSE 1 END)
            , [StartOffsetBytes] =
                CASE
                    WHEN @BatchText IS NULL THEN NULL
                    WHEN @StatementStartOffsetBytes IS NULL THEN 0
                    ELSE @StatementStartOffsetBytes
                END
            , [EndOffsetBytes] =
                CASE
                    WHEN @BatchText IS NULL THEN NULL
                    WHEN @StatementEndOffsetBytes IS NULL OR @StatementEndOffsetBytes = -1
                        THEN DATALENGTH(@BatchText)
                    ELSE @StatementEndOffsetBytes
                END
    ),
    [Validated] AS
    (
        SELECT
              [BatchText]
            , [BatchLengthBytes]
            , [HasOffsets]
            , [StartOffsetBytes]
            , [EndOffsetBytes]
            , [IsOffsetValid] = CONVERT
              (
                  bit,
                  CASE
                      WHEN [BatchText] IS NULL THEN 0
                      WHEN [StartOffsetBytes] IS NULL OR [EndOffsetBytes] IS NULL THEN 0
                      WHEN [StartOffsetBytes] < 0 OR [EndOffsetBytes] < 0 THEN 0
                      WHEN [StartOffsetBytes] > [EndOffsetBytes] THEN 0
                      WHEN [StartOffsetBytes] > [BatchLengthBytes] THEN 0
                      WHEN [EndOffsetBytes] > [BatchLengthBytes] THEN 0
                      WHEN [StartOffsetBytes] % 2 <> 0 OR [EndOffsetBytes] % 2 <> 0 THEN 0
                      ELSE 1
                  END
              )
        FROM [Normalized]
    ),
    [Extracted] AS
    (
        SELECT
              [BatchText]
            , [BatchLengthBytes]
            , [HasOffsets]
            , [StartOffsetBytes]
            , [EndOffsetBytes]
            , [IsOffsetValid]
            , [StatementText] =
                CASE
                    WHEN [BatchText] IS NULL THEN NULL
                    WHEN [IsOffsetValid] = 0 THEN NULL
                    ELSE SUBSTRING
                    (
                          [BatchText]
                        , ([StartOffsetBytes] / 2) + 1
                        , (([EndOffsetBytes] - [StartOffsetBytes]) / 2) + 1
                    )
                END
        FROM [Validated]
    ),
    [Measured] AS
    (
        SELECT
              [BatchText]
            , [BatchLengthBytes]
            , [HasOffsets]
            , [StartOffsetBytes]
            , [EndOffsetBytes]
            , [IsOffsetValid]
            , [StatementText]
            , [StatementLengthBytes] = DATALENGTH([StatementText])
            , [StatementStartCharacter] =
                CASE WHEN [IsOffsetValid] = 1 THEN ([StartOffsetBytes] / 2) + 1 END
            , [StatementStartLine] =
                CASE
                    WHEN [IsOffsetValid] = 0 THEN NULL
                    ELSE 1
                       + LEN(LEFT([BatchText], [StartOffsetBytes] / 2))
                       - LEN(REPLACE(LEFT([BatchText], [StartOffsetBytes] / 2), NCHAR(10), N''))
                END
        FROM [Extracted]
    )
    SELECT
          [HasStatementOffsets] = [HasOffsets]
        , [IsStatementOffsetValid] = [IsOffsetValid]
        , [StatementStartOffsetBytes] = CASE WHEN [HasOffsets] = 1 THEN [StartOffsetBytes] END
        , [StatementEndOffsetBytes] =
            CASE
                WHEN [HasOffsets] = 0 THEN NULL
                WHEN @StatementEndOffsetBytes IS NULL OR @StatementEndOffsetBytes = -1 THEN -1
                ELSE [EndOffsetBytes]
            END
        , [StatementStartCharacter]
        , [StatementEndCharacter] =
            CASE
                WHEN [StatementLengthBytes] IS NULL OR [StatementLengthBytes] = 0 THEN NULL
                ELSE [StatementStartCharacter] + ([StatementLengthBytes] / 2) - 1
            END
        , [StatementStartLine]
        , [StatementEndLine] =
            CASE
                WHEN [StatementText] IS NULL THEN NULL
                ELSE [StatementStartLine]
                   + LEN([StatementText])
                   - LEN(REPLACE([StatementText], NCHAR(10), N''))
            END
        , [StatementCharacterCount] = CASE WHEN [StatementLengthBytes] IS NULL THEN NULL ELSE [StatementLengthBytes] / 2 END
        , [BatchCharacterCount] = CASE WHEN [BatchLengthBytes] IS NULL THEN NULL ELSE [BatchLengthBytes] / 2 END
        , [StatementText]
    FROM [Measured]
);
GO
