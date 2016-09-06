<h2 align = "center">物联网与无线网络实验资源</h2>
<h3>卫星网络轨迹和轨道可视化</h3>
+ <strong>资源地址</strong>：可以从[这里](http://www.ee.surrey.ac.uk/Personal/L.Wood/ns/sat-plot-scripts/)下载到最新的工具包。
+ <strong>运行要求</strong>：Ubuntu系统需要安装最新的perl和xfig工具，具体安装命令如下：
<pre><code>
$sudo apt-get install perl xfig
</code></pre>
+ <strong>文件说明</strong>：coordinate_system.fig (用于xfig的经纬度标记框架)；preamble.fig (运行任何xfig画图命令前需要的文件)；plot.tr(plotpath输入的样本数据包trace信息，其由仿真产生)；sats.dump (plotsats输入的样本拓扑dump数据)；plotsats (根据sats.dump数据绘制星座位置)；plotpath (绘制plot.tr中记录的数据包所经过的路径)；plotboth (同时实现plotsats和plotpath的功能)；plot_sats.pl和plot_path.pl (perl脚本，运行一系列xfig命令)；1.gif, 2.gif, 3.gif, 4.gif (不同的背景图片)；polar_coordinate_system.fig (frame for azimuthal equidistant plot)；polarplotsats, polarplotpath, polarplotboth - as above, for az. eq.；polar_plot_sats.pl and polar_plot_path.pl - really do all the work.；azeq.gif - azimuthal equidistant background map graphic

+ 用法
<pre><code>
plotsats [<-file name> <-map name> -links <-arrows> -plane <-alpha num> -nonum]
plotpath [<-file name> <-map name> -links <-arrows> -hopcount -packet n]
plotboth [<-file name> <-map name> -links <-arrows> -hopcount -packet n]
</pre></code>

+ 例子
<pre><code>
plotsats -map 1 -links -plane -alpha 24 -file sats.dump
plotsats -map 2.gif -links -plane
plotsats -map 3 -links -plane -nonum
plotsats -map 4 -nonum
plotpath -hopcount -map 3 -file plot.tr
plotpath -map 2 -links
</pre></code>

+ 帮助
<pre><code>
plot_sats.pl -help
plot_path.pl -help
</pre></code>




