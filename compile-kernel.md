<h3>Compile and Install Linux Kernel</h3>
+ <strong>Why Build a Custom Kernel</strong>: Compiling a custom Linux kernel has its advantages and disadvantages. To change the kernel’s behavior, one had to compile and then reboot into a new Linux. Most of the functionality in the Linux kernel contained in modules that can be dynamically loaded and unloaded from the kernel as necessary. 
+ <strong>[Prerequisites](http://www.cyberciti.biz/faq/debian-ubuntu-building-installing-a-custom-linux-kernel/)</strong>:You need to install the following packages on a Debian or Ubuntu Linux to compiler the Linux kernel:
<ul>
	<li><strong>git</strong> : Fast, scalable, distributed revision control system. You can grab the latest source code using the git command.</li>
	<li><strong>fakeroot</strong>: Tool for simulating superuser privileges. Useful to build .deb files.</li>
	<li><strong>build-essential </strong>: Tools for building the Linux kernel such as GCC compiler and related tools on a Debian or Ubuntu Linux based system.</li>
	<li><strong>ncurses-dev</strong>: Developer’s libraries for ncurses. This is used by menuconfig while configuring the kernel options.</li>
	<li><strong>kernel-package</strong>: Utility for building Linux kernel related Debian packages.</li>
	<li><strong>xz-utils</strong>: XZ-format compression utilities to decompress the Linux kernel tar ball.</li>
	<li><strong>Disk space</strong>: 10 GB or more free disk space.</li>
	<li><strong>Time</strong>: Kernel compilation may take quite a while, depending on the power of your machine.</li>
</ul>
Using the following commands to install some tools:
<pre><code>
$ sudo apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc kernel-package wget
</pre></code>
+ <strong>Compile Kernel</strong>: Download kernel source code using the following command:
<pre><code>
$ git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
$ git checkout v4.7.2
</pre></code>
and then compile kernel as following:
<pre><code>
$ cd linux-4.7.2
$ cp /boot/config-$(uname -r) .config
$ make menuconfig
$ make-kpkg clean
$ fakeroot make-kpkg  --initrd --revision jiangxianliang.001 --append-to-version -20160906 kernel_image kernel_headers
</pre></code>
To speed up the compile process pass the -j option (-j 16 means you are using all 16 cores to compile the Linux kernel):
<pre><code>
$ fakeroot make-kpkg  --initrd --revision jiangxianliang.001 --append-to-version -20160906 kernel_image kernel_headers -j 16
</pre></code>
<ul>
	<li>--initrd : Create an initrd image.</li>
	<li>--revision=jiangxianliang.001 : Set custom revision for your kernel such as jiangxianliang.001 or -jiangxianliang.001-custom-kernel etc.</li>
	<li>--append-to-version</li>
	<li>kernel_image : This target produces a Debian package of the Linux kernel source image, and any modules configured in the kernel configuration file .config.</li>
	<li>kernel_headers : This target produces a Debian package of the Linux kernel header image.</li>
</ul>
Verify kernel deb files:
<pre><code>
$ ls  ../*.deb
</pre></code>
+ <strong>Installing a Custom Kernel</strong>: Type the following dpkg command to install a custom kernel on your system:
<pre><code>
$ sudo dpkg -i linux-headers-4.7.2-20160906_jiangxianliang.001_amd64.deb
$ sudo dpkg -i linux-image-4.7.2-20160906_jiangxianliang.001_amd64.deb
</pre></code>
Reboot and verify the new kernel. 



