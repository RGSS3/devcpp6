using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace Update
{
    public partial class Update : Form
    {
        const string baseUrl = "https://cdn.jsdelivr.net/gh/RGSS3/devcpp6/";

        private string downloadUrl = "";

        UpdateLite updater; bool fullUpdate = false; int lasterVersion;

        public Update()
        {
            InitializeComponent(); LoadDLL();

            updater = new UpdateLite();

            if (!File.Exists(Application.StartupPath + "/version"))
                File.WriteAllText(Application.StartupPath + "/version", "601");

            lasterVersion = int.Parse(updater.GetVersion(baseUrl + "version"));
            int currentVersion = int.Parse(File.ReadAllText(Application.StartupPath + "/version"));

            downloadUrl = updater.GetUrlInfo(baseUrl + "UpdateInfo/donwload_url");

            if (lasterVersion - currentVersion > 0)
            {
                if (DialogResult.Yes == MessageBox.Show("检查到新版本，是否更新？", "更新", MessageBoxButtons.YesNo))
                {
                    try { foreach (Process p in Process.GetProcessesByName("devcpp")) p.Kill(); } catch { }

                    if (lasterVersion - currentVersion >= 2)
                    {
                        fullUpdate = true;
                        updater.Download(downloadUrl + "devcpp.zip", DownloadProgressCallback, DownloadCompletedCallback);
                    }
                    else updater.Download(downloadUrl + "devcpp_i.zip", DownloadProgressCallback, DownloadCompletedCallback);
                }
            }
            else Environment.Exit(0);
        }

        private void Update_Load(object sender, EventArgs e) { }

        private void DownloadProgressCallback(object sender, System.Net.DownloadProgressChangedEventArgs e)
        {
            progressBar.Value = e.ProgressPercentage;
            Application.DoEvents();
        }

        private void DownloadCompletedCallback(object sender, AsyncCompletedEventArgs e)
        {
            Thread.Sleep(300); Application.DoEvents();

            string md5Url = "";

            if (fullUpdate) md5Url = updater.GetVersion(baseUrl + "UpdateInfo/md5");
            else md5Url = updater.GetVersion(baseUrl + "UpdateInfo/md5_i");

            if (updater.CheckMD5(md5Url))
            {
                File.WriteAllText(Application.StartupPath + "/version", lasterVersion.ToString());

                Thread.Sleep(300); Application.DoEvents();

                Process process = new Process();
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.FileName = Application.StartupPath + "/devcpp.exe";
                process.Start();

                Process.Start("https://devcpp6.com");

                Environment.Exit(0);
            }
            else
            {
                MessageBox.Show("下载文件错误，更新失败！");
                Environment.Exit(0);
            }
        }

        private void LoadDLL()
        {
            string dllFilePath = Application.StartupPath + "/ICSharpCode.SharpZipLib.dll";

            if (!File.Exists(dllFilePath))
            {
                File.WriteAllBytes(dllFilePath, Resource1.ICSharpCode_SharpZipLib);
            }
        }
    }
}
