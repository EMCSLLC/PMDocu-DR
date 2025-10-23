@{
    RootModule = ''
    ModuleVersion = '1.0.0'

    Rules = @{
        # ─── General Style Rules ───────────────────────────────
        PSAlignAssignmentStatement = @{
            Enable = $false # prevents multiple spaces before/after '='
        }
        PSAvoidUsingAlias = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOperator = $true # ensures single space around '=' and + - etc.
            CheckPipe = $true
            CheckSeparator = $true
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseCorrectCasing = @{
            Enable = $true
        }
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true # aligns with OTBS preset
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
        }

        # ─── Maintainability / Best Practices ─────────────────
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSUseCmdletCorrectly = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSAvoidUsingEmptyCatchBlock = @{
            Enable = $true
        }

        # ─── Security / Reliability ───────────────────────────
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }

        # ─── Suppress cosmetic or noisy rules ─────────────────
        PSReviewUnusedParameter = @{
            Enable = $false
        }
        PSProvideCommentHelp = @{
            Enable = $false
        }
        PSUseBOMForUnicodeEncodedFile = @{
            Enable = $false
        }
    }

    ExcludeRules = @(
        # Optional overrides — keep disabled unless required
        'PSAvoidGlobalVars'
    )
}
