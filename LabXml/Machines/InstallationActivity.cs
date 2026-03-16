using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Xml.Serialization;

namespace AutomatedLab
{
    [Serializable]
    public class InstallationActivity
    {
        private Path dependencyFolder;
        private string scriptFilePath;
        private bool keepFolder;
        private Path isoImage;
        private bool isCustomRole;
        private bool doNotUseCredSsp;
        private bool asJob;

        // Serialized list of PSVariable
        public string SerializedVariables { get; set; }

        // Serialized list of PSFunctionInfo
        public string SerializedFunctions { get; set; }

        // Serialized hashtable
        public string SerializedProperties { get; set; }

        public Path DependencyFolder
        {
            get { return dependencyFolder; }
            set { dependencyFolder = value; }
        }

        public string ScriptFilePath { get; set; }
        
        public string RemoteScriptFilePath { get; set; }


        public bool KeepFolder
        {
            get { return keepFolder; }
            set { keepFolder = value; }
        }

        [XmlElement(IsNullable = true)]
        public Path IsoImage
        {
            get { return isoImage; }
            set { isoImage = value; }
        }

        public bool IsCustomRole
        {
            get { return isCustomRole; }
            set { isCustomRole = value; }
        }

        public string RoleName { get; set; }

        public bool DoNotUseCredSsp
        {
            get { return doNotUseCredSsp; }
            set { doNotUseCredSsp = value; }
        }

        public bool AsJob
        {
            get { return asJob; }
            set { asJob = value; }
        }

        public override string ToString()
        {
            return RoleName;
        }
    }
}