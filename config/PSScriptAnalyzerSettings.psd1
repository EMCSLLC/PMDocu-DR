@{
    IncludeDefaultRules = $true

    Rules               = @{
        # ─── General Style Rules ───────────────────────────────
        PSAlignAssignmentStatement                     = @{
            Enable = $false # prevents multiple spaces before/after '='
        }
        PSAvoidUsingAlias                              = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace                      = @{
            Enable = $true
        }
        PSUseConsistentWhitespace                      = @{
            Enable          = $true
            CheckInnerBrace = $true
            CheckOpenBrace  = $true
            CheckOperator   = $true # ensures single space around '=' and + - etc.
            CheckPipe       = $true
            CheckSeparator  = $true
        }
        PSUseConsistentIndentation                     = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseCorrectCasing                             = @{
            Enable = $true
        }
        PSPlaceOpenBrace                               = @{
            Enable     = $true
            OnSameLine = $true # aligns with OTBS preset
        }
        PSPlaceCloseBrace                              = @{
            Enable       = $true
            NewLineAfter = $true
        }

        # Prefer readability for generated Markdown/content blocks
        PSAvoidLongLines                               = @{
            Enable            = $true
            MaximumLineLength = 240 # allow longer Markdown strings without noise
        }

        # ─── Maintainability / Best Practices ─────────────────
        PSUseDeclaredVarsMoreThanAssignments           = @{
            Enable = $true
        }
        PSUseApprovedVerbs                             = @{
            Enable = $true
        }
        PSUseCmdletCorrectly                           = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters               = @{
            Enable = $true
        }
        PSAvoidUsingEmptyCatchBlock                    = @{
            Enable = $true
        }

        # ─── Security / Reliability ───────────────────────────
        PSAvoidUsingPlainTextForPassword               = @{
            Enable = $true
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }

        # ─── Suppress cosmetic or noisy rules ─────────────────
        PSReviewUnusedParameter                        = @{
            Enable = $false
        }
        PSProvideCommentHelp                           = @{
            Enable = $false
        }
        PSUseBOMForUnicodeEncodedFile                  = @{
            Enable = $false
        }
    }

    ExcludeRules        = @(
        # Optional overrides — keep disabled unless required
        'PSAvoidGlobalVars'
    )
}
