using ICSharpCode.SharpZipLib.Zip;
using System;
using System.ComponentModel;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace Update
{
    public class UpdateLite
    {
        private string downloadPath = Path.GetTempPath() + "devcpp.zip";

        public WebClient webClient = new WebClient();

        public string GetUrlInfo(string url)
        {
            string result = "";

            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            HttpWebResponse resp = (HttpWebResponse)req.GetResponse();
            Stream stream = resp.GetResponseStream();

            try { using (StreamReader reader = new StreamReader(stream)) { result = reader.ReadToEnd(); } }
            finally { stream.Close(); }

            return result;
        }

        public string GetVersion(string url)
        {
            string result = GetUrlInfo(url);

            if (string.IsNullOrEmpty(result)) result = "601";

            return result;
        }

        public void Download(string url, DownloadProgressChangedEventHandler OnProgress, AsyncCompletedEventHandler OnCompleted)
        {
            webClient.DownloadProgressChanged += OnProgress;
            webClient.DownloadFileCompleted += OnCompleted;

            webClient.DownloadFileAsync(new Uri(url), downloadPath);
        }

        public bool CheckMD5(string md5)
        {
            FileStream file = new FileStream(downloadPath, FileMode.Open);

            MD5 md5CSP = new MD5CryptoServiceProvider();
            byte[] hash = md5CSP.ComputeHash(file);

            file.Close();

            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < hash.Length; i++) sb.Append(hash[i].ToString("x2"));
            string fileMD5 = sb.ToString();

            if (fileMD5 == md5)
            {
                (new FastZip()).ExtractZip(downloadPath, Directory.GetCurrentDirectory(), "");
                return true;
            }
            else return false;
        }
    }
}
