#!/usr/bin/perl

# http://blog.csdn.net/p793049488/article/details/40422975

use Cwd;
use POSIX qw(strftime);

use strict;
use File::Spec;
use File::Path;
use Config::Tiny;



sub writeComments {
	my $fileFullPath = shift;
	my $fileName = shift;
	my $subFileName = shift;

    if (!($subFileName =~ /AuthorityExtendDaoImpl\.java/)) {
    	return;
    }
    print "fileName: $fileName  java file: $subFileName\n";

    print "fileFullPath: $fileFullPath \n";


    # 处理java文件=====================START
    print "-----------------------------------------------------------------------------\n";
    print "处理java文件 START\n";
    my $javaCode = "";
    my $line;
    if (open(FILEFULLPATH, $fileFullPath)) {
        while ($line = <FILEFULLPATH>) {
            # print "line: $line";

            if ($line =~ /\@param ([^"]+) ([^"]+)/) {
            	my $value1 = $1;
            	my $value2 = $2;

            	print "value1:valu1begin $value1 value1end    value2:value2begin $value2 value2end\n";

            	if ($value2 eq "") {
            		print ("lkkkkkkkkkkkkk");
            	}

            }

        }
        close(FILEFULLPATH);
        

        # open(OUTFILEFULLPATH, ">$fileFullPath");
        # print OUTFILEFULLPATH ($javaCode);
        # close(OUTFILEFULLPATH);
    } else {
        print "无法打开java文件: $fileFullPath\n";
    }
    
    print "处理java文件 END\n";
    # 处理java文件=====================END


}




# 读取配置文件
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read('./config.ini');

my $goalPath = $Config->{comment}->{goalPath};
# print "goalPath:		$goalPath\n";
# local $\ ="\n";#当前模块的每行输出加入换行符    



my $count = 0;	
# 目录路径
# 文件数组
my @cases;
# 判断目录是否存在
if (-d $goalPath) {
	# 目录数组
    my @files;
    my $dh;
    push(@files, $goalPath);
    while (@files) {
		my $fileOrDir = $files[0];
		# 若是目录执行以下操作
        if (-d $fileOrDir) {
        	# 打开目录句柄,若失败打印错误信息
            opendir $dh, $fileOrDir or die $!;
            my @filesOrDirs = readdir $dh;
            # 过滤掉以"."和".."的文件,即UNIX下的隐藏文件
            my @filterFilesOrDirs = grep { /^[^\.]/ } @filesOrDirs;
            foreach (@filterFilesOrDirs) {
            	my $subFileName = $_;
            	# print "subFileName: $subFileName\n";
            	# 连接目录名和文件名形成一个完整的文件路径
        		my $fileFullPath = File::Spec->catfile($fileOrDir, $subFileName);
        		if (-d $fileFullPath) {
					# print "dirs : $fileFullPath\n";
    				push(@files, $fileFullPath);
    			} elsif ($subFileName =~ /([^"]+)\.java/) {
    				# print "java file: $fileFullPath\n";
    				my $fileName = $1;
    				# print "fileName: $fileName  java file: $subFileName\n";
    				writeComments(($fileFullPath, $fileName, $subFileName));
    				$count++;
        			push(@cases, $fileOrDir);
    			} else {
    				# print "files not ext: $fileFullPath\n";
        			# push(@cases, $fileOrDir);
    			}
            }
            closedir $dh;
        }
        shift @files;
    }
} else {
	print "file not exist\n";
    @cases = ($goalPath);
}


print "count : $count\n";

# print "texttttttt\n";
# print "@cases";
# print $_ foreach @cases;#打印文件列表





`pause`;

















