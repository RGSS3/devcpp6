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

        UpdateLite updater; bool fullUpdate = false;

        public Update()
        {
            InitializeComponent();

            updater = new UpdateLite();

            if (!File.Exists(Directory.GetCurrentDirectory() + "/version"))
                File.WriteAllText(Directory.GetCurrentDirectory() + "/version", "601");

            int lasterVersion = int.Parse(updater.GetVersion(baseUrl + "version"));
            int currentVersion = int.Parse(File.ReadAllText(Directory.GetCurrentDirectory() + "/version"));

            if (lasterVersion - currentVersion > 0)
            {
                if (DialogResult.Yes == MessageBox.Show("检查到新版本，是否更新？", "更新", MessageBoxButtons.YesNo))
                {
                    try { foreach (Process p in Process.GetProcessesByName("devcpp")) p.Kill(); } catch { }

                    if (lasterVersion - currentVersion >= 2)
                    {
                        fullUpdate = true;
                        updater.Download(baseUrl + "Build/devcpp.zip", DownloadProgressCallback, DownloadCompletedCallback);
                    }
                    else updater.Download(baseUrl + "Build/devcpp_i.zip", DownloadProgressCallback, DownloadCompletedCallback);
                }
            }

            Application.Exit();
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

            if (fullUpdate) md5Url = updater.GetVersion(baseUrl + "/Build/md5");
            else md5Url = updater.GetVersion(baseUrl + "/Build/md5_i");

            if (updater.CheckMD5(md5Url))
            {
                Thread.Sleep(300); Application.DoEvents();

                Process process = new Process();
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.FileName = Directory.GetCurrentDirectory() + "/devcpp.exe";
                process.Start();

                Application.Exit();
            }
            else
            {
                MessageBox.Show("下载文件错误，更新失败！");
                Application.Exit();
            }
        }
    }
}
