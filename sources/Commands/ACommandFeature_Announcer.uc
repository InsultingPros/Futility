/**
 *      Announcer for `ACommandFeature`.
 *      Copyright 2022 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class ACommandFeature_Announcer extends CommandAnnouncer;

var private AnnouncementVariations enabledFeature, disabledFeature;
var private AnnouncementVariations swappedConfig, pendingConfigSaved;
var private AnnouncementVariations showCurrentConfig, showPendingConfig;
var private AnnouncementVariations configCreated, configRemoved, configEdited;
var private AnnouncementVariations configEditedNew;
var private AnnouncementVariations pendingConfigSavedPublic;
var private AnnouncementVariations pendingConfigSavedPrivate;
var private AnnouncementVariations autoEnabled, removedAutoEnabled;
var private AnnouncementVariations failedAlreadyNoAutoEnabled;
var private AnnouncementVariations failedAlreadySameAutoEnabled;
var private AnnouncementVariations failedConfigAlreadyExists;
var private AnnouncementVariations failedConfigDoesNotExists;
var private AnnouncementVariations failedToLoadFeatureClass;
var private AnnouncementVariations failedNoConfigProvided, failedConfigMissing;
var private AnnouncementVariations failedCannotEnableFeature;
var private AnnouncementVariations failedNoConfigClass, failedBadConfigName;
var private AnnouncementVariations failedAlreadyEnabled, failedAlreadyDisabled;
var private AnnouncementVariations failedNoDataForConfig, failedExpectedObject;
var private AnnouncementVariations failedBadPointer, failedPendingConfigMissing;

protected function Finalizer()
{
    FreeVariations(enabledFeature);
    FreeVariations(disabledFeature);
    FreeVariations(swappedConfig);
    FreeVariations(pendingConfigSaved);
    FreeVariations(showCurrentConfig);
    FreeVariations(showPendingConfig);
    FreeVariations(configCreated);
    FreeVariations(configRemoved);
    FreeVariations(configEdited);
    FreeVariations(configEditedNew);
    FreeVariations(pendingConfigSavedPublic);
    FreeVariations(pendingConfigSavedPrivate);
    FreeVariations(autoEnabled);
    FreeVariations(removedAutoEnabled);
    FreeVariations(failedAlreadyNoAutoEnabled);
    FreeVariations(failedAlreadySameAutoEnabled);
    FreeVariations(failedConfigAlreadyExists);
    FreeVariations(failedConfigDoesNotExists);
    FreeVariations(failedToLoadFeatureClass);
    FreeVariations(failedNoConfigProvided);
    FreeVariations(failedConfigMissing);
    FreeVariations(failedCannotEnableFeature);
    FreeVariations(failedNoConfigClass);
    FreeVariations(failedBadConfigName);
    FreeVariations(failedAlreadyEnabled);
    FreeVariations(failedAlreadyDisabled);
    FreeVariations(failedNoDataForConfig);
    FreeVariations(failedExpectedObject);
    FreeVariations(failedBadPointer);
    FreeVariations(failedPendingConfigMissing);
    super.Finalizer();
}

public final function AnnounceEnabledFeature(
    class<Feature>  featureClass,
    BaseText        configName)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!enabledFeature.initialized)
    {
        enabledFeature.initialized = true;
        enabledFeature.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextPositive enabled} with config"
            @ "\"%2\"");
        enabledFeature.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextPositive enabled} feature"
            @ "{$TextEmphasis `%1`} with config \"%2\"");
    }
    templates = MakeArray(enabledFeature);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgClass(featureClass).Arg(configName);
    }
    MakeAnnouncement(enabledFeature);
}

public final function AnnounceDisabledFeature(class<Feature> featureClass)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!disabledFeature.initialized)
    {
        disabledFeature.initialized = true;
        disabledFeature.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextNegative disabled}");
        disabledFeature.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNegative disabled} feature"
            @ "{$TextEmphasis `%1`}");
    }
    templates = MakeArray(disabledFeature);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgClass(featureClass);
    }
    MakeAnnouncement(disabledFeature);
}

public final function AnnounceSwappedConfig(
    class<Feature>  featureClass,
    BaseText        oldConfig,
    BaseText        newConfig)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!swappedConfig.initialized)
    {
        swappedConfig.initialized = true;
        swappedConfig.toSelfReport = _.text.MakeTemplate_S(
            "Config for feature {$TextEmphasis `%1`} {$TextNeutral swapped}"
            @ "from \"%2\" to \"%3\"");
        swappedConfig.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral swapped} config for feature"
            @ "{$TextEmphasis `%1`} from \"%2\" to \"%3\"");
    }
    templates = MakeArray(swappedConfig);
    for (i = 0; i < templates.length; i += 1)
    {
        templates[i]
            .Reset()
            .ArgClass(featureClass)
            .Arg(oldConfig)
            .Arg(newConfig);
    }
    MakeAnnouncement(swappedConfig);
}

public final function AnnouncePublicPendingConfigSaved(
    class<Feature> featureClass)
{
    local int                   i;
    local array<TextTemplate>   templates;

    if (!pendingConfigSavedPublic.initialized)
    {
        pendingConfigSavedPublic.initialized = true;
        pendingConfigSavedPublic.toSelfReport = _.text.MakeTemplate_S(
            "Active config for feature {$TextEmphasis `%1`} was"
            @ "{$TextNeutral modified}");
        pendingConfigSavedPublic.toSelfPublic = _.text.MakeTemplate_S(
            "%%instigator%% {$TextNeutral modified} active config for feature"
            @ "{$TextEmphasis `%1`}");
    }
    templates = MakeArray(pendingConfigSavedPublic);
    for (i = 0; i < templates.length; i += 1) {
        templates[i].Reset().ArgClass(featureClass);
    }
    MakeAnnouncement(pendingConfigSavedPublic);
}

public final function AnnouncePrivatePendingConfigSaved(
    class<Feature> featureClass)
{
    if (!pendingConfigSavedPrivate.initialized)
    {
        pendingConfigSavedPrivate.initialized = true;
        pendingConfigSavedPrivate.toSelfReport = _.text.MakeTemplate_S(
            "Active config for feature {$TextEmphasis `%1`} was"
            @ "{$TextNeutral modified}");
    }
    pendingConfigSavedPrivate.toSelfReport
        .Reset()
        .ArgClass(featureClass);
    MakeAnnouncement(pendingConfigSavedPrivate);
}

public final function AnnounceCurrentConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!showCurrentConfig.initialized)
    {
        showCurrentConfig.initialized = true;
        showCurrentConfig.toSelfReport = _.text.MakeTemplate_S(
            "Current config \"%2\" for feature {$TextEmphasis `%1`}:");
    }
    showCurrentConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(showCurrentConfig);
}

public final function AnnouncePendingConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!showPendingConfig.initialized)
    {
        showPendingConfig.initialized = true;
        showPendingConfig.toSelfReport = _.text.MakeTemplate_S(
            "Pending config \"%2\" for feature {$TextEmphasis `%1`}:");
    }
    showPendingConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(showPendingConfig);
}

public final function AnnounceConfigCreated(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!configCreated.initialized)
    {
        configCreated.initialized = true;
        configCreated.toSelfReport = _.text.MakeTemplate_S(
            "{$TextPositive Created config} \"%2\" for feature"
            @ "{$TextEmphasis `%1`}");
    }
    configCreated.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(configCreated);
}

public final function AnnounceConfigRemoved(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!configRemoved.initialized)
    {
        configRemoved.initialized = true;
        configRemoved.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNegative Removed config} \"%2\" for feature"
            @ "{$TextEmphasis `%1`}");
    }
    configRemoved.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(configRemoved);
}

public final function AnnounceConfigEdited(
    class<Feature>  featureClass,
    BaseText        config,
    BaseText        pathToValue,
    BaseText        oldValue,
    BaseText        newValue)
{
    if (!configEdited.initialized)
    {
        configEdited.initialized = true;
        configEdited.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNeutral Edited config} \"%2\" for feature"
            @ "{$TextEmphasis `%1`} by replacing old value %4 at \"%3\""
            @ "with new value %5");
    }
    configEdited.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config)
        .Arg(pathToValue)
        .Arg(oldValue)
        .Arg(newValue);
    MakeAnnouncement(configEdited);
}

public final function AnnounceConfigNewValue(
    class<Feature>  featureClass,
    BaseText        config,
    BaseText        pathToValue,
    BaseText        newValue)
{
    if (!configEditedNew.initialized)
    {
        configEditedNew.initialized = true;
        configEditedNew.toSelfReport = _.text.MakeTemplate_S(
            "{$TextNeutral Edited config} \"%2\" for feature"
            @ "{$TextEmphasis `%1`} by adding value %4 at \"%3\"");
    }
    configEditedNew.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config)
        .Arg(pathToValue)
        .Arg(newValue);
    MakeAnnouncement(configEditedNew);
}

public final function AnnounceAutoEnabledConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!autoEnabled.initialized)
    {
        autoEnabled.initialized = true;
        autoEnabled.toSelfReport = _.text.MakeTemplate_S(
            "Config \"%2\" for feature {$TextEmphasis `%1`} will now be"
            @ "{$TextPositive auto-enabled}!");
    }
    autoEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(autoEnabled);
}

public final function AnnounceRemovedAutoEnabledConfig(
    class<Feature> featureClass)
{
    if (!removedAutoEnabled.initialized)
    {
        removedAutoEnabled.initialized = true;
        removedAutoEnabled.toSelfReport = _.text.MakeTemplate_S(
            "No config for feature {$TextEmphasis `%1`} will now be"
            @ "{$TextPositive auto-enabled}!");
    }
    removedAutoEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass);
    MakeAnnouncement(removedAutoEnabled);
}

public final function AnnounceFailedAlreadyNoAutoEnabled(
    class<Feature> featureClass)
{
    if (!failedAlreadyNoAutoEnabled.initialized)
    {
        failedAlreadyNoAutoEnabled.initialized = true;
        failedAlreadyNoAutoEnabled.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Cannot remove} auto-enabled config status for"
            @ "feature {$TextEmphasis `%1`}: it already has"
            @ "{$TextNeutral no auto-enabled config}!");
    }
    failedAlreadyNoAutoEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass);
    MakeAnnouncement(failedAlreadyNoAutoEnabled);
}

public final function AnnounceFailedAlreadySameAutoEnabled(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedAlreadySameAutoEnabled.initialized)
    {
        failedAlreadySameAutoEnabled.initialized = true;
        failedAlreadySameAutoEnabled.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Cannot make} config \"%2\" auto-enabled for feature"
            @ "{$TextEmphasis `%1`}: it already"
            @ "{$TextNeutral is auto-enabled}!");
    }
    failedAlreadySameAutoEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedAlreadySameAutoEnabled);
}

public final function AnnounceFailedConfigAlreadyExists(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedConfigAlreadyExists.initialized)
    {
        failedConfigAlreadyExists.initialized = true;
        failedConfigAlreadyExists.toSelfReport = _.text.MakeTemplate_S(
            "Config \"%2\" for feature {$TextEmphasis `%1`}"
            @ "{$TextFailure already exists}");
    }
    failedConfigAlreadyExists.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedConfigAlreadyExists);
}
    
    public final function AnnounceFailedConfigDoesNotExist(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedConfigDoesNotExists.initialized)
    {
        failedConfigDoesNotExists.initialized = true;
        failedConfigDoesNotExists.toSelfReport = _.text.MakeTemplate_S(
            "Config \"%2\" for feature {$TextEmphasis `%1`}"
            @ "{$TextFailure doesn't exist}");
    }
    failedConfigDoesNotExists.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedConfigDoesNotExists);
}

public final function AnnounceFailedToLoadFeatureClass(BaseText failedClassName)
{
    if (!failedToLoadFeatureClass.initialized)
    {
        failedToLoadFeatureClass.initialized = true;
        failedToLoadFeatureClass.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Failed} to load feature class {$TextEmphasis `%1`}");
    }
    failedToLoadFeatureClass.toSelfReport.Reset().Arg(failedClassName);
    MakeAnnouncement(failedToLoadFeatureClass);
}

public final function AnnounceFailedNoConfigProvided(
    class<Feature> featureClass)
{
    if (!failedNoConfigProvided.initialized)
    {
        failedNoConfigProvided.initialized = true;
        failedNoConfigProvided.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure No config specified} and {$TextFailure no"
            @ "auto-enabled config} exists for feature {$TextEmphasis `%1`}");
    }
    failedNoConfigProvided.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedNoConfigProvided);
}

public final function AnnounceFailedConfigMissing(BaseText config)
{
    if (!failedConfigMissing.initialized)
    {
        failedConfigMissing.initialized = true;
        failedConfigMissing.toSelfReport = _.text.MakeTemplate_S(
            "Specified config \"%1\" {$TextFailure doesn't exist}");
    }
    failedConfigMissing.toSelfReport.Reset().Arg(config);
    MakeAnnouncement(failedConfigMissing);
}

public final function AnnounceFailedPendingConfigMissing(BaseText config)
{
    if (!failedPendingConfigMissing.initialized)
    {
        failedPendingConfigMissing.initialized = true;
        failedPendingConfigMissing.toSelfReport = _.text.MakeTemplate_S(
            "Specified config \"%1\" {$TextFailure doesn't have} any pending"
            @ "changes");
    }
    failedPendingConfigMissing.toSelfReport.Reset().Arg(config);
    MakeAnnouncement(failedPendingConfigMissing);
}

public final function AnnounceFailedCannotEnableFeature(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedCannotEnableFeature.initialized)
    {
        failedCannotEnableFeature.initialized = true;
        failedCannotEnableFeature.toSelfReport = _.text.MakeTemplate_S(
            "Something went {$TextFailure wrong}, {$TextFailure failed} to"
            @ "enable feature {$TextEmphasis `%1`} with config \"%2\"");
    }
    failedCannotEnableFeature.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedCannotEnableFeature);
}

public final function AnnounceFailedNoConfigClass(
    class<Feature> featureClass)
{
    if (!failedNoConfigClass.initialized)
    {
        failedNoConfigClass.initialized = true;
        failedNoConfigClass.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} {$TextFailure does not have} config"
            @ "class! This is most likely caused by its faulty"
            @ "implementation");
    }
    failedNoConfigClass.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedNoConfigClass);
}

public final function AnnounceFailedBadConfigName(BaseText configName)
{
    if (!failedBadConfigName.initialized)
    {
        failedBadConfigName.initialized = true;
        failedBadConfigName.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Cannot create} a config with invalid name \"%1\"");
    }
    failedBadConfigName.toSelfReport.Reset().Arg(configName);
    MakeAnnouncement(failedBadConfigName);
}

public final function AnnounceFailedAlreadyDisabled(
    class<Feature> featureClass)
{
    if (!failedAlreadyDisabled.initialized)
    {
        failedAlreadyDisabled.initialized = true;
        failedAlreadyDisabled.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Cannot disable} feature {$TextEmphasis `%1`}: it is"
            @ "already {$TextNegative disabled}");
    }
    failedAlreadyDisabled.toSelfReport.Reset().ArgClass(featureClass);
    MakeAnnouncement(failedAlreadyDisabled);
}

public final function AnnounceFailedAlreadyEnabled(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedAlreadyEnabled.initialized)
    {
        failedAlreadyEnabled.initialized = true;
        failedAlreadyEnabled.toSelfReport = _.text.MakeTemplate_S(
            "{$TextFailure Cannot enable} feature {$TextEmphasis `%1`}: it is"
            @ "already {$TextPositive enabled} with specified config \"%2\"");
    }
    failedAlreadyEnabled.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedAlreadyEnabled);
}

public final function AnnounceFailedNoDataForConfig(
    class<Feature>  featureClass,
    BaseText        config)
{
    if (!failedNoDataForConfig.initialized)
    {
        failedNoDataForConfig.initialized = true;
        failedNoDataForConfig.toSelfReport = _.text.MakeTemplate_S(
            "Feature {$TextEmphasis `%1`} is {$TextFailure missing data} for"
            @ "config \"%2\"");
    }
    failedNoDataForConfig.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config);
    MakeAnnouncement(failedNoDataForConfig);
}

public final function AnnounceFailedExpectedObject()
{
    if (!failedExpectedObject.initialized)
    {
        failedExpectedObject.initialized = true;
        failedExpectedObject.toSelfReport = _.text.MakeTemplate_S(
            "Value change {$TextFailure failed}, because when changing"
            @ "the value of the whole config, a JSON object must be provided");
    }
    MakeAnnouncement(failedExpectedObject);
}

public final function AnnounceFailedBadPointer(
    class<Feature>  featureClass,
    BaseText        config,
    BaseText        pointer)
{
    if (!failedBadPointer.initialized)
    {
        failedBadPointer.initialized = true;
        failedBadPointer.toSelfReport = _.text.MakeTemplate_S(
            "Provided JSON pointer \"%3\" is {$TextFailure invalid} for config"
            @ "\"%2\" of feature {$TextEmphasis `%1`}");
    }
    failedBadPointer.toSelfReport
        .Reset()
        .ArgClass(featureClass)
        .Arg(config)
        .Arg(pointer);
    MakeAnnouncement(failedBadPointer);
}

defaultproperties
{
}