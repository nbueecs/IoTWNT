<h2 align = "center">物联网与无线网络实验资源</h2>

<h3>NS2真实流量仿真：基于SUMO, Open Street</h3>

该实验的大致过程：从Open Street中导出地图，格式：*.osm.xml；用SUMO中的脚本经过许多步骤将上述的地图转为NS2可读取的移动场景；编写NS2实验脚本，导入上述得到的移动场景，进行实验。需要注意，在编写实验脚本时，需要主要(x, y)的坐标值和总的节点数。详细过程如下：

=======
+ <strong>环境要求</strong>：安装SUMO和NS2。其中，NS2安装不再赘述，请参考我们的教材。对于SUMO，Ubuntu系统的在线安装命令为：
<pre><code>
$sudo add-apt-repository pap:sumo/stable
$sudo apt-get update
$sudo apt-get install sumo sumo-doc sumo-tools
</code></pre>
安装好SUMO后，还需下载最新SUMO源码，因要用到其含有的脚本进行地图转换。下载地址：[sumo-0.27.1.tar.gz](https://sourceforge.net/projects/sumo/files/sumo/version%200.27.1/sumo-src-0.27.1.tar.gz/download)。下载后将压缩包解压到自己喜欢的位置，然后将文件夹名字重命名为自己容易记住的名字，紧接着将该文件夹的根目录路径添加到环境变量中，即为“~/.bashrc”文件。
<pre><code>
export SUMO_HOME=/home/\<path_to_sumo\>/sumo
</code></pre>
+ <strong>导出地图</strong>：打开浏览器，输入[Open Street](http://www.openstreetmap.org)的地址并回车；进入[Open Street](http://www.openstreetmap.org)主页后，在左上角的搜索框中搜索指定位置的区域，并单击顶部的“导出”按钮；在左侧选择“手动选择不同的区域”，并在右侧选定需要导出的地图区域，然后单击左侧的“导出”按钮进行导出，默认文件名为：map.osm.xml。在本实验中，我们将该文件重命名为：test.osm.xml。
+ <strong>移动场景产生</strong>：逐条执行下面的命令(注意：文件名test跟前面导出后重命名的相同，并将“$SUMO_HOME/data/”中的osmPolyconvert.typ.xml拷贝到与test.osm.xml相同的目录下)：
<pre><code>
$netconvert --osm-files test.osm.xml -o test.net.xml
$polyconvert --osm-files test.osm --net-file test.net.xml --type-file osmPolyconvert.typ.xml -o test.poly.xml
$python $SUMO_HOME/tools/randomTrips.py -n test.net.xml -r test.rou.xml -e 100 -l
</code></pre>
执行完上述命令后，会得到几个关键的文件：test.net.xml、test.poly.xml和test.rou.xml。接下来，创建文件名为：test.sumo.cfg的文件，然后将下面的代码放入其中并保存。
<pre><code>
\<configuration\>
 		\<input\>
			\<net-file value="test.net.xml"/\> 
			\<route-files value="test.rou.xml"/\>
         		\<additional-files value="test.poly.xml"/\>
     		\</input\>
		\<time\>
			\<begin value="0"/>
			\<end value="100"/>
			\<step-length value="0.1"/>
		\</time>
\</configuration>
</code></pre>
执行下面的命令，可得到可视化的地图。
<pre><code>
$sumo-gui test.sumo.cfg
</code></pre>
将地图数据导出为NS2可识别的场景文件，命令如下：
<pre><code>
$sumo -c test.sumo.cfg --fcd-output test.sumo.xml
$python $SUMO_HOME/sumo/tools/traceExporter.py --fcd-input test.sumo.xml --ns2config-output test.tcl --ns2activity-output activity.tcl --ns2mobility-output mobility.tcl​
</code></pre>
经过上述步骤，可以得到两个关键的 TCL文件：test.tcl和mobility.tcl，其中，第1个文件包含了地图范围和节点数量的信息，用于写实验脚本；第2个文件为移动场景，在实验脚本中导入即可。

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




