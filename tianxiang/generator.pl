#!/usr/bin/perl

# http://blog.csdn.net/p793049488/article/details/40422975

use Cwd;
use POSIX qw(strftime);
use File::Copy;

my $dateString = "";
# 当前目录的全路径
my $curExeDir = getcwd;
print "当前执行目录的全路径: $curExeDir\n";
# 使用正斜杠分割字符串
@directoryNames = split(/\//, $curExeDir);
print "使用正斜杠分割字符串后的数组:@directoryNames\n";
# 数组的最大下标
$directoryNamesMaxIndex = $#directoryNames;
print "数组的最大下标:$directoryNamesMaxIndex\n";
# 数组的最大长度
$directoryNamesLength = $directoryNamesMaxIndex + 1;
print "数组的最大长度:$directoryNamesLength\n";
# pl文件所在的当前文件夹名称
$currentDirectoryName = $directoryNames[$directoryNamesLength - 1];
print "pl文件所在的当前文件夹名称:$currentDirectoryName\n";
print "\n\n\n";


#删除旧的src目录和其下的所有内容
rmtree('./src');
#新建一个src目录
mkpath('./src', 1, 0777);

my $resultCodeDirName = "resultCode";

#删除旧的resultCode目录和其下的所有内容
rmtree('./'.$resultCodeDirName);
#新建一个src目录
mkpath('./'.$resultCodeDirName, 1, 0777);


my $generatorJarFile = "../common/generator.jar";
my $generatorXmlFile = "./generator.xml";

my $javaGeneratorCode = "java -jar ".$generatorJarFile." -configfile ".$generatorXmlFile." -overwrite";
print "javaGeneratorCode: $javaGeneratorCode\n";

system($javaGeneratorCode);


#!/usr/bin/perl

# `java -jar ../common/generator.jar -configfile ./generator.xml -overwrite`;

# generator 自动代码生成工具生成的初步代码是在 src/tmp中


use File::Path;
use Config::Tiny;
# 读取配置文件
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read('./config.ini');

# 项目名称
my $projectName = $Config->{section}->{projectName};
my $projectFullName = $Config->{section}->{projectFullName};


my $projectRootDir = $Config->{section}->{projectRootDir};
my $javaProjectDir = $Config->{section}->{javaProjectDir};

my $author = $Config->{section}->{author};
my $version = $Config->{section}->{version};
my $copyright = $Config->{section}->{copyright};
# 是否是固定的时间,默认是false
my $confirmedDateTime = $Config->{section}->{confirmedDateTime};
# 如果是固定的时间,那么此值就是固定时间
my $confirmedDateTimeString = $Config->{section}->{confirmedDateTimeString};

my $splitFlag = "_";

my $originEntityPackage = "";
my $originEntityDir = "";
my $originDaoPackage = "";
my $originDaoDir = "";
my $originMapperPackage = "";
my $originMapperDir = "";
# 原始的Dao接口名称
my $originDaoInterfaceName = "";
my $primaryKeyId = "";

my $curEntityKeyClassName = "";
my $curEntityClassName = "";
my $curTableName = "";
my $curModule = "";
my $curProject = "";

my $destMappingFileName = "";
my $destEntityPackage = "";
my $destDaoPackage = "";
my $destDaoImplPackage = "";
my $destDaoInterfaceName = "";
my $destDaoImplClassName = "";
my $destDaoImplRepositoryValue = "";


my $daoImplContent = "";



my $headerName = "";

my $configInfo = "";
my @configItems ;
my $replacePackage = "";
my $replacePackageDir = "";


my $srcDir = "./src";
my $startDir = "";

my $inputEntityFile = "";
my $inputEntityKeyFile = "";
my $outputEntityFileDir = "";
my $outputEntityFile = "";
my $outputEntityKeyFile = "";
my $projectEntityFileDir = "";
my $projectEntityFile = "";
my $projectEntityKeyFile = "";
my $javeEntityFile = "";

# entity 是否有xxxKey 的父类, 表是联合主键
my $entityHaveBaseClass = 0;

my $inputMapperFile = "";
my $outputMapperFileDir = "";
my $outputMapperExtendFileDir = "";
my $outputMapperFile = "";
my $projectMapperFileDir = "";
my $projectMapperFile = "";
my $javeMapperFile = "";

my $javeMapperExtendFileDir = "";

my $inputDaoFile = "";
my $outputDaoFileDir = "";
my $outputDaoFile = "";
my $outputDaoImplFileDir = "";
my $outputDaoImplFile = "";
my $projectDaoFileDir = "";
my $projectDaoFile = "";
my $projectDaoImplFileDir = "";
my $projectDaoImplFile = "";
my $javeDaoFile = "";


my $javeDaoImplFile = "";



# mapping dao daoImpl 注释用到的
# insertSelective 一定要在 insert 前面,要不然会出现错误, 因为是按照顺序去查找的
my @keywords = ("BaseResultMap", 
    "Base_Column_List", 
    "deleteByPrimaryKey", 
    "insertSelective", 
    "insert", 
    "selectByPrimaryKey", 
    "updateByPrimaryKeySelective", 
    "updateByPrimaryKey",
    "queryByCondition");
my @daoImplSQLActions = ("", "", "delete", "insert", "insert", "selectOne", "update", "update", "selectList");

# 获取属性的描述
# 先按照class.propertyName的方式找,如果没有找到那就直接按照propertyName方式去找
sub getPropertyNameDesc {
    my $tmpPropertyName = $_[0];

    if (isDefaultPrimaryKey($tmpPropertyName)) {
        return "id";
    } 

    my $tmpClassPropertyName = lc($curEntityClassName).".".lc($tmpPropertyName);
    my $tmpResult = $Config->{analysis}->{$tmpClassPropertyName};
    if ($tmpResult eq "") {
        if (isDefaultPrimaryKey($tmpPropertyName)) {
            return "id";
        } else {
            return $Config->{analysis}->{lc($tmpPropertyName)};
        }
    } else {
        return $tmpResult;
    }
}

sub getClassNameDesc {
    return $Config->{className}->{lc($curEntityClassName)};
}

sub getMappingComments {
    my $line = $_[0];
    my $newLine = "";
    foreach $keyword (@keywords) {
        # id 前面需要加一个空格,要不然有一个 refid=""
        my $condition = " id=\"".$keyword."\"";
        if ($line =~ /$condition/) {
            $newLine = "  <!--".$Config->{mapping}->{$keyword}."-->\n";
            # 找到就跳出循环
            last;
        }
    }
    return $newLine;
}

sub isDefaultPrimaryKey {
    my $tmpParam = $_[0];
    return lc($tmpParam) eq lc($primaryKeyId);
}

sub getDaoMethodComments {
    my $line = $_[0];
    my $newLine = "";
    my $size = @keywords;

    # 联合主键表的参数名称是: record 而非 id
    my $primaryKeyParamName = $entityHaveBaseClass == 1 ? "key" : $primaryKeyId;
    my $primaryKeyParamType = $entityHaveBaseClass == 1 ? $curEntityKeyClassName : "int";
    # 参数名称
    my @paramNames = ("", "", $primaryKeyParamName, "record", "record", $primaryKeyParamName, "record", "record", "condition");
    # 参数类型
    my @paramTypes = ("", "", $primaryKeyParamType, $curEntityClassName, $curEntityClassName, $primaryKeyParamType, $curEntityClassName, $curEntityClassName, "String");
    # 返回类型
    my @returnTypes = ("", "", "int", $curEntityClassName, $curEntityClassName, $curEntityClassName, $curEntityClassName, $curEntityClassName, "List<".$curEntityClassName.">");

    # 这两个输出的结果是完完全全不一样
    # print "size: $size\n";
    # print "keywords: @keywords\n";

    for (my $i = 0; $i < $size; $i++) {
        my $keyword = $keywords[$i];
        my $paramType = $paramTypes[$i];
        my $paramName = $paramNames[$i];
        my $daoImplSQLAction = $daoImplSQLActions[$i];
        my $returnType = @returnTypes[$i];
        if ($line =~ /$keyword/) {


            my $methodComments = $Config->{mapping}->{$keyword};
            my $paramNameDesc = "";
            my $returnTypeDesc = "";
            my $seeParamTypeDesc = "";


            if ($keyword eq "deleteByPrimaryKey") {
                if ($entityHaveBaseClass == 1) {
                    $paramNameDesc = "联合主键";
                }
                else {
                    $paramNameDesc = "id";
                }
                $returnTypeDesc = "int";
                $seeParamTypeDesc = $paramType;
            }
            elsif ($keyword eq "selectByPrimaryKey") {
                if ($entityHaveBaseClass == 1) {
                    $paramNameDesc = "联合主键";
                }
                else {
                    $paramNameDesc = "id";
                }
                $returnTypeDesc = $destEntityPackage.".".$returnType;
                $seeParamTypeDesc = $paramType;
            }
            elsif ($keyword eq "queryByCondition") {
                $paramNameDesc = "查询条件";
                $returnTypeDesc = "List<".$destEntityPackage.".".$curEntityClassName.">";
                $seeParamTypeDesc = $paramType;
            }
            else {
                $paramNameDesc = $Config->{className}->{lc($paramType)}."记录";
                $returnTypeDesc = $destEntityPackage.".".$paramType;
                $seeParamTypeDesc = $returnTypeDesc;
            }

            
            # print "keyword: $keyword\n"; 
            # print "paramType: $paramType\n"; 
            # print "paramName: $paramName\n"; 
            # print "paramNameDesc: $paramNameDesc\n"; 
            # print "returnTypeDesc: $returnTypeDesc\n"; 
            # print "returnType: $returnType\n";  

            $newLine .= "    /**\n";
            $newLine .= "     *\n";
            $newLine .= "     * \@Method : ".$keyword."\n";
            $newLine .= "     * \@Description : ".$methodComments."\n";
            $newLine .= "     * \@param ".$paramName." : ".$paramNameDesc."\n";
            $newLine .= "     * \@return : ".$returnTypeDesc."\n";
            $newLine .= "     * \@author : ".$author."\n";
            $newLine .= "     * \@CreateDate : ".$dateString."\n";
            $newLine .= "     *\n";
            $newLine .= "     */\n";

            # dao impl
            $daoImplContent .= "    /**\n";
            $daoImplContent .= "     *\n";
            $daoImplContent .= "     * ".$methodComments."\(非 Javadoc\)\n";
            $daoImplContent .= "     * \@param ".$paramName." ".$paramNameDesc."\n";
            $daoImplContent .= "     * \@return : ".$returnTypeDesc."\n";
            $daoImplContent .= "     * \@see ".$destDaoPackage.".".$destDaoInterfaceName."\#".$keyword."\(".$seeParamTypeDesc."\)\n";
            $daoImplContent .= "     *\n";
            $daoImplContent .= "     */\n";
            $daoImplContent .= "    public ".$returnType." ".$keyword."\(".$paramType." ".$paramName."\) {\n";
            $sqlAction = "this.getSqlSession\(\).".$daoImplSQLAction."\(NAMESPACE + \".".$keyword."\", ".$paramName."\);";

            if ($keyword eq "deleteByPrimaryKey" || $keyword eq "queryByCondition") {
                $daoImplContent .= "        return ".$sqlAction."\n";
            } elsif ($keyword eq "selectByPrimaryKey") {
                $daoImplContent .= "        Object object = ".$sqlAction."\n";
                $daoImplContent .= "        if \(!\(object instanceof ".$curEntityClassName."\)\) {\n";
                $daoImplContent .= "            return null;\n";
                $daoImplContent .= "        }\n";
                $daoImplContent .= "        return \(".$curEntityClassName."\)object;\n";
            } else {
                $daoImplContent .= "        ".$sqlAction."\n";
                $daoImplContent .= "        return ".$paramName.";\n";
            }

            $daoImplContent .= "    }\n";
            $daoImplContent .= "\n";
            
            
            # 跳出循环
            last;
        }
    }

    if ($line =~ /}/) { # 添加一个按照条件查询的接口
       
        my $addLine = "    List<".$curEntityClassName."> queryByCondition(String condition);\n";
        $newLine = getDaoMethodComments($addLine);
    

        $daoImplContent .= "}\n";
    }


    $newLine .= $line;

    return $newLine;
}



# 导出entity.java
sub exportEntityFile {
    my $entityCode = "";
    if (open(ENTITYFILE, $inputEntityFile)) {
        while ($line = <ENTITYFILE>) {
            my $newLine = "";
            #处理package包路径，将generator生成的包路径，替换为工程结构的包路径
            if ($line =~ /package.$originEntityPackage/) { # 包名
                $newLine = "package ".$destEntityPackage.";\n";
            } elsif ($line =~ /public class /) { # 类注释

                if ($line =~ /public class ([^"]+) extends /) {
                    $entityHaveBaseClass = 1;
                }
                else {
                    $entityHaveBaseClass = 0;
                }
                # print "line: $line\n";
                # print "entityHaveBaseClass: $entityHaveBaseClass\n";


                $newLine .= "/**\n";
                $newLine .= " *\n";
                $newLine .= " * \@Project : ".$projectFullName."\n";
                $newLine .= " * \@Package : ".$destEntityPackage."\n";
                $newLine .= " * \@Class : ".$curEntityClassName."\n";
                $newLine .= " * \@Description : ".getClassNameDesc()."层实体类\n";
                $newLine .= " * \@author : ".$author."\n";
                $newLine .= " * \@CreateDate : ".$dateString."\n";
                $newLine .= " * \@version : ".$version."\n";
                $newLine .= " * \@Copyright : ".$copyright."\n";
                $newLine .= " * \@Reviewed : \n";
                $newLine .= " * \@UpdateLog : Name    Date    Reason/Contents\n";
                $newLine .= " *             ---------------------------------------\n";
                $newLine .= " *                ***      ****    ****\n";
                $newLine .= " *\n";
                $newLine .= " */\n";
                $newLine .= $line;
            } elsif ($line =~ /private ([^"]+) ([^"]+);/) { # 属性注释
                my $propertyType = $1;
                my $propertyName = $2;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                # print "pro  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";

                # print "输出propertyType:  $propertyType\n";
                # print "输出propertyName:  $propertyName\n";
                # print "输出propertyNameDesc:  $propertyNameDesc\n";
                $newLine .= "    /**".$propertyNameDesc."**/\n";
                $newLine .= $line;
            } elsif ($line =~ /public void set([^"]+)\(([^"]+) ([^"]+)\)/) { # set 方法
                my $propertyName = $1;
                my $paramType = $2;
                my $paramName = $3;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                # print "propertyName:   $propertyName \n";
                # print "propertyNameDesc:   $propertyNameDesc \n";

                # print "set  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";
                # print "输出 set propertyName:  $propertyName\n";
                # print "输出 set propertyNameDesc:  $propertyNameDesc\n";
                # print "输出 set paramType:  $paramType\n";
                # print "输出 set paramName:  $paramName\n";
                $newLine .= "    /**\n";
                $newLine .= "     *\n";
                $newLine .= "     * \@Method : set".$propertyName."\n";
                $newLine .= "     * \@Description : 设置".$propertyNameDesc."\n";
                $newLine .= "     * \@param ".$paramName." : ".$propertyNameDesc."\n";
                $newLine .= "     * \@author : ".$author."\n";
                $newLine .= "     * \@CreateDate : ".$dateString."\n";
                $newLine .= "     *\n";
                $newLine .= "     */\n";
                $newLine .= $line;
            } elsif ($line =~ /public ([^"]+) get([^"]+)\(\)/) {
                my $propertyName = $2;
                my $returnType = $1;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                # print "get  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";

                # print "输出 get propertyName:  $propertyName\n";
                # print "输出 get propertyNameDesc:  $propertyNameDesc\n";
                # print "输出 get returnType:  $returnType\n";
                $newLine .= "    /**\n";
                $newLine .= "     *\n";
                $newLine .= "     * \@Method : get".$propertyName."\n";
                $newLine .= "     * \@Description : 获取".$propertyNameDesc."\n";
                $newLine .= "     * \@return : ".$returnType."\n";
                $newLine .= "     * \@author : ".$author."\n";
                $newLine .= "     * \@CreateDate : ".$dateString."\n";
                $newLine .= "     *\n";
                $newLine .= "     */\n";
                $newLine .= $line;
            } else {
                $newLine = $line;
            }
            # print "输出Line:     $line";
            # print "输出newLine:  $newLine";
            $entityCode .= $newLine;
        }
        close(ENTITYFILE);
        

        mkpath($outputEntityFileDir, 1, 0777);

        # print "inputEntityFile:  $inputEntityFile\n";
        # print "outputEntityFileDir:  $outputEntityFileDir\n";
        # print "outputEntityFile:  $outputEntityFile\n";

        open(OUTENTITY, ">$outputEntityFile");
        print OUTENTITY ($entityCode);
        close(OUTENTITY);


        # delete old file
        unlink($projectEntityFile);
        # copy new file
        copy($outputEntityFile, $projectEntityFileDir);



    } else {
        print "无法打开Entity文件: $inputEntityFile\n";
    }

    if ($entityHaveBaseClass == 1) {
        exportEntityKeyFile();
    }
    
}

# 导出entityKey.java
sub exportEntityKeyFile {

    my $entityCode = "";
    if (open(ENTITYFILE, $inputEntityKeyFile)) {
        while ($line = <ENTITYFILE>) {
            my $newLine = "";
            #处理package包路径，将generator生成的包路径，替换为工程结构的包路径
            if ($line =~ /package.$originEntityPackage/) { # 包名
                $newLine = "package ".$destEntityPackage.";\n";
            } elsif ($line =~ /public class /) { # 类注释


                $newLine .= "/**\n";
                $newLine .= " *\n";
                $newLine .= " * \@Project : ".$projectFullName."\n";
                $newLine .= " * \@Package : ".$destEntityPackage."\n";
                $newLine .= " * \@Class : ".$curEntityKeyClassName."\n";
                $newLine .= " * \@Description : ".getClassNameDesc()."层实体类\n";
                $newLine .= " * \@author : ".$author."\n";
                $newLine .= " * \@CreateDate : ".$dateString."\n";
                $newLine .= " * \@version : ".$version."\n";
                $newLine .= " * \@Copyright : ".$copyright."\n";
                $newLine .= " * \@Reviewed : \n";
                $newLine .= " * \@UpdateLog : Name    Date    Reason/Contents\n";
                $newLine .= " *             ---------------------------------------\n";
                $newLine .= " *                ***      ****    ****\n";
                $newLine .= " *\n";
                $newLine .= " */\n";
                $newLine .= $line;
            } elsif ($line =~ /private ([^"]+) ([^"]+);/) { # 属性注释
                my $propertyType = $1;
                my $propertyName = $2;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                # print "pro  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";

                # print "输出propertyType:  $propertyType\n";
                # print "输出propertyName:  $propertyName\n";
                # print "输出propertyNameDesc:  $propertyNameDesc\n";
                $newLine .= "    /**".$propertyNameDesc."**/\n";
                $newLine .= $line;
            } elsif ($line =~ /public void set([^"]+)\(([^"]+) ([^"]+)\)/) { # set 方法
                my $propertyName = $1;
                my $paramType = $2;
                my $paramName = $3;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                print "propertyName:   $propertyName \n";
                print "propertyNameDesc:   $propertyNameDesc \n";

                # print "set  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";
                # print "输出 set propertyName:  $propertyName\n";
                # print "输出 set propertyNameDesc:  $propertyNameDesc\n";
                # print "输出 set paramType:  $paramType\n";
                # print "输出 set paramName:  $paramName\n";
                $newLine .= "    /**\n";
                $newLine .= "     *\n";
                $newLine .= "     * \@Method : set".$propertyName."\n";
                $newLine .= "     * \@Description : 设置".$propertyNameDesc."\n";
                $newLine .= "     * \@param ".$paramName." : ".$propertyNameDesc."\n";
                $newLine .= "     * \@author : ".$author."\n";
                $newLine .= "     * \@CreateDate : ".$dateString."\n";
                $newLine .= "     *\n";
                $newLine .= "     */\n";
                $newLine .= $line;
            } elsif ($line =~ /public ([^"]+) get([^"]+)\(\)/) {
                my $propertyName = $2;
                my $returnType = $1;
                my $propertyNameDesc = getPropertyNameDesc($propertyName);

                # print "get  propertyName:       $curEntityClassName      $propertyName    $propertyNameDesc\n";

                # print "输出 get propertyName:  $propertyName\n";
                # print "输出 get propertyNameDesc:  $propertyNameDesc\n";
                # print "输出 get returnType:  $returnType\n";
                $newLine .= "    /**\n";
                $newLine .= "     *\n";
                $newLine .= "     * \@Method : get".$propertyName."\n";
                $newLine .= "     * \@Description : 获取".$propertyNameDesc."\n";
                $newLine .= "     * \@return : ".$returnType."\n";
                $newLine .= "     * \@author : ".$author."\n";
                $newLine .= "     * \@CreateDate : ".$dateString."\n";
                $newLine .= "     *\n";
                $newLine .= "     */\n";
                $newLine .= $line;
            } else {
                $newLine = $line;
            }
            # print "输出Line:     $line";
            # print "输出newLine:  $newLine";
            $entityCode .= $newLine;
        }
        close(ENTITYFILE);
        

        mkpath($outputEntityFileDir, 1, 0777);

        # print "inputEntityFile:  $inputEntityFile\n";
        # print "outputEntityFileDir:  $outputEntityFileDir\n";
        # print "outputEntityFile:  $outputEntityFile\n";

        open(OUTENTITY, ">$outputEntityKeyFile");
        print OUTENTITY ($entityCode);
        close(OUTENTITY);


        # delete old file
        unlink($projectEntityKeyFile);
        # copy new file
        copy($outputEntityKeyFile, $projectEntityFileDir);



    } else {
        print "无法打开Entity文件: $inputEntityKeyFile\n";
    }
}

sub exportMapperFile {
    my $mapperXml = "";
    my $xmlCode = "";
    print "inputMapperFile:  $inputMapperFile\n";
    if (open(XMLFILE, $inputMapperFile)) {
        while ($line = <XMLFILE>) {
            my $newLine = "";
            $newLine .= getMappingComments($line);
            $newLine .= $line;
            # print "输出line   ".$line;
            # print "输出newline".$newLine;
            $xmlCode .= $newLine;
        }
        close(XMLFILE);
        
        # 不存在queryByCondition方法时的处理
        unless($xmlCode =~ /"queryByCondition"/) {
            my $sqlQueryByCondition = "  <select id=\"queryByCondition\" resultMap=\"BaseResultMap\" parameterType=\"java.lang.String\" >\n";
            $addCode = "";
            $addCode .= getMappingComments($sqlQueryByCondition);
            $addCode .= $sqlQueryByCondition;
            $addCode .= "    select\n";
            $addCode .= "    <include refid=\"Base_Column_List\" />\n";
            $addCode .= "    from ".$tableName."\n";
            $addCode .= "    where \${value}\n";
            $addCode .= "  </select>\n";
            $addCode .= "</mapper>\n";

            # print "输出addCode".$addCode;
            if($xmlCode =~ /"Base_Column_List"/){ #存在 Base_Column_List
                $xmlCode =~ s/\<\/mapper\>/$addCode/;
            }
        }
        
        #替换mapper文件中的包路径
        #generator生成的类type为cn.yiyizuche.yyoa.entity.类名，需要替换成工程的包路径下的类
        my $oldType = $originEntityPackage.".".$curEntityClassName;
        my $newType = $destEntityPackage.".".$curEntityClassName;

        # print "输出旧xmlCode".$xmlCode;
        $xmlCode =~ s/$oldType/$newType/g;
        # print "输出新xmlCode".$xmlCode;
        
        #根据目录结构创建文件路径，然后将文件写入
        mkpath($outputMapperFileDir, 1, 0777); #参数1为是否打印目录，0777为系统内部权限
        mkpath($outputMapperExtendFileDir, 1, 0777); 
        # print "outputMapperFileDir:  $outputMapperFileDir\n";
        # print "outputMapperExtendFileDir:  $outputMapperExtendFileDir\n";
        # print "outputMapperFile:  $outputMapperFile\n";
        open(DATAFILE, ">$outputMapperFile");
        print DATAFILE ($xmlCode);
        close(DATAFILE);


        # delete old file
        unlink($projectMapperFile);
        # copy new file
        copy($outputMapperFile, $projectMapperFileDir);
    } else {
        print "无法打开文件: $inputMapperFile\n";
    }
}


sub exportDaoAndDaoImplFile {
    # 根据generator生成的IDao接口生成实现
    my $idaoCode = "";
    print "inputDaoFile:  $inputDaoFile\n";

    #读取接口文件获取主键类型
    if (open(DAOFILE, $inputDaoFile)) {
        # 开始处理dao文件的时候,先把daoImplContent置空
        $daoImplContent = "";

        # 是否添加了import
        my $haveAddImport = 0;
        while($line = <DAOFILE>) {
            my $newLine = "";
            if ($line =~ /package /) {
                $newLine .= "package ".$destDaoPackage.";\n";

                # dao impl
                $daoImplContent .= "package ".$destDaoImplPackage.";\n";
                $daoImplContent .= "\n";

            } elsif ($line =~ /import/) {
                if ($haveAddImport == 0) {
                    $newLine .= "import ".$destEntityPackage.".".$curEntityClassName.";\n";
                    if ($entityHaveBaseClass == 1) {
                        $newLine .= "import ".$destEntityPackage.".".$curEntityClassName."Key;\n";
                    }
                    $newLine .= "import java.util.List;\n";
                    
                    $daoImplContent .= "import java.util.List;\n";
                    $daoImplContent .= "import org.springframework.stereotype.Repository;\n";
                    $daoImplContent .= "import com.yicoding.common.base.MyBatisDao;\n";
                    $daoImplContent .= "import ".$destEntityPackage.".".$curEntityClassName.";\n";
                    if ($entityHaveBaseClass == 1) {
                        $daoImplContent .= "import ".$destEntityPackage.".".$curEntityClassName."Key;\n";
                    }
                    $daoImplContent .= "import ".$destDaoPackage.".".$destDaoInterfaceName.";\n";

                    $haveAddImport = 1;
                }

            } elsif ($line =~ /public interface/) {
                $newLine .= "/**\n";
                $newLine .= " *\n";
                $newLine .= " * \@Project : ".$projectFullName."\n";
                $newLine .= " * \@Package : ".$destDaoPackage."\n";
                $newLine .= " * \@Class : ".$destDaoInterfaceName."\n";
                $newLine .= " * \@Description : ".getClassNameDesc()."层接口\n";
                $newLine .= " * \@author : ".$author."\n";
                $newLine .= " * \@CreateDate : ".$dateString."\n";
                $newLine .= " * \@version : ".$version."\n";
                $newLine .= " * \@Copyright : ".$copyright."\n";
                $newLine .= " * \@Reviewed : \n";
                $newLine .= " * \@UpdateLog : Name    Date    Reason/Contents\n";
                $newLine .= " *             ---------------------------------------\n";
                $newLine .= " *                ***      ****    ****\n";
                $newLine .= " *\n";
                $newLine .= " */\n";
                $newLine .= "public interface ".$destDaoInterfaceName." {\n";


                # dao impl
                $daoImplContent .= "/**\n";
                $daoImplContent .= " *\n";
                $daoImplContent .= " * \@Project : ".$projectFullName."\n";
                $daoImplContent .= " * \@Package : ".$destDaoImplPackage."\n";
                $daoImplContent .= " * \@Class : ".$destDaoInterfaceName."Impl\n";
                $daoImplContent .= " * \@Description : ".getClassNameDesc()."层实现类\n";
                $daoImplContent .= " * \@author : ".$author."\n";
                $daoImplContent .= " * \@CreateDate : ".$dateString."\n";
                $daoImplContent .= " * \@version : ".$version."\n";
                $daoImplContent .= " * \@Copyright : ".$copyright."\n";
                $daoImplContent .= " * \@Reviewed : \n";
                $daoImplContent .= " * \@UpdateLog : Name    Date    Reason/Contents\n";
                $daoImplContent .= " *             ---------------------------------------\n";
                $daoImplContent .= " *                ***      ****    ****\n";
                $daoImplContent .= " *\n";
                $daoImplContent .= " */\n";
                $daoImplContent .= "\@Repository\(value = \"".$destDaoImplRepositoryValue."\"\)\n";
                $daoImplContent .= "public class ".$destDaoImplClassName." extends MyBatisDao implements ".$destDaoInterfaceName." {\n";
                $daoImplContent .= "\n";
                $daoImplContent .= "    /**Maaping.xml对应的Namespace*/\n";
                $daoImplContent .= "    protected static final String NAMESPACE = \"".$destMappingFileName."\";\n";

            } else {
                $newLine .= getDaoMethodComments($line);

                # print "输出Line   :".$line;

            }
            # print "输出Line   :".$line;
            # print "输出newLine:".$newLine;
            $idaoCode .= $newLine;
        }
        close(DAOFILE);


        # print "idaoCode:    $idaoCode\n";
        # print "daoImplContent:    $daoImplContent\n";

        mkpath($outputDaoFileDir, 1, 0777);
        # print "outputDaoFileDir:  $outputDaoFileDir\n";
        # print "outputDaoFile:  $outputDaoFile\n";
        open(OUTDAO, ">$outputDaoFile");
        print OUTDAO ($idaoCode);
        close(OUTDAO);


        # delete old file
        unlink($projectDaoFile);
        # copy new file
        copy($outputDaoFile, $projectDaoFileDir);

        #生成dao impl实现路径
        mkpath($outputDaoImplFileDir, 1, 0777);
        # print "outputDaoImplFileDir:  $outputDaoImplFileDir\n";
        # print "outputDaoImplFile:  $outputDaoImplFile\n";
        open(OUTFILE, ">$outputDaoImplFile");
        print OUTFILE ($daoImplContent);
        close(OUTFILE);


        # delete old file
        unlink($projectDaoImplFileDir);
        # copy new file
        copy($outputDaoImplFile, $projectDaoImplFile);

    } else {
        print "无法打开文件: $inputDaoFile\n";
    }

}




if (open(GENERATORFILE, $generatorXmlFile)) {
    while ($line = <GENERATORFILE>) {
        if ($line =~ /<javaModelGenerator/) {
            if ($line =~ /targetPackage="([^"]+)"/) {
                $originEntityPackage = $1;
                $originEntityDir = $1;
                $originEntityDir =~ s/\./\//g;
                print "originEntityPackage:  $originEntityPackage\n";
                print "originEntityDir:      $originEntityDir\n";
            }
        }

        if ($line =~ /<javaClientGenerator/) {
            if ($line =~ /targetPackage="([^"]+)"/) {
                $originDaoPackage = $1;
                $originDaoDir = $1;
                $originDaoDir =~ s/\./\//g;
                print "originDaoPackage:     $originDaoPackage\n";
                print "originDaoDir:         $originDaoDir\n";
            }
        }
        
        if ($line =~ /<sqlMapGenerator/) {
            if ($line =~ /targetPackage="([^"]+)"/) {
                $originMapperPackage = $1;
                $originMapperDir = $1;
                $originMapperDir =~ s/\./\//g;
                print "originMapperPackage:  $originMapperPackage\n";
                print "originMapperDir:      $originMapperDir\n";
            }
        }
        
        #扫描到数据表处理的xml配置
        if ($line =~ /table tableName="([^"]+)" domainObjectName="([^"]+)" /) {

            $dateString = strftime "%Y-%m-%d %H:%M:%S", localtime;
            if ($confirmedDateTime) {
                $dateString = $confirmedDateTimeString;
            }
            print "dateString:  $dateString\n";

            $curTableName = $1;
            $curEntityClassName = $2;
            $curEntityKeyClassName = $curEntityClassName."Key";

            # 是否包含分隔符"_"
            if ($curTableName =~ /$splitFlag/) {
                @array = split(/$splitFlag/, $curTableName);
                $curModule = @array[0];
            } else {
                $curModule = $curTableName;
            }
            
            # 当模块名为sys和ou时，项目名为common；模块名为其他时，项目名为配置的项目名称；该设置为处理包结构中sys和ou部分的位置
            if ("sys" eq $curModule || "ou" eq $curModule) { 
                $curProject = "common";
            } else {
                $curProject = $projectName;
            }

            $headerName = $curEntityClassName;
            # 首字母变小写
            $headerName =~ s/\b\w/\l$&/g;

            $configInfo = $Config->{package}->{$curTableName};
            @configItems = split(/\|/, $configInfo);
            $replacePackage = $configItems[0];
            $replacePackageDir = $replacePackage;
            $replacePackageDir =~ s/\./\//g;
            

            $destMappingFileName = $curEntityClassName."Mapper";
            $destEntityPackage = $replacePackage.".entity";
            $destDaoPackage = $replacePackage.".dao";
            $destDaoImplPackage = $replacePackage.".dao.impl";
            $originDaoInterfaceName = "I".$curEntityClassName."Dao";
            $destDaoInterfaceName = $curEntityClassName."Dao";
            $destDaoImplClassName = $destDaoInterfaceName."Impl";
            $destDaoImplRepositoryValue = $headerName."Dao";
            $primaryKeyId = $headerName."Id";

            $startDir = "./".$resultCodeDirName;

            $inputEntityFile = $srcDir."/".$originEntityDir."/".$curEntityClassName.".java";
            $inputEntityKeyFile = $srcDir."/".$originEntityDir."/".$curEntityClassName."Key.java";
            $outputEntityFileDir = $startDir."/".$projectName."-base/src/main/java/".$replacePackageDir."/entity";
            $outputEntityFile = $outputEntityFileDir."/".$curEntityClassName.".java";
            $outputEntityKeyFile = $outputEntityFileDir."/".$curEntityClassName."Key.java";
            $projectEntityFileDir = $projectRootDir."/".$projectName."-base/src/main/java/".$replacePackageDir."/entity";
            $projectEntityFile = $projectEntityFileDir."/".$curEntityClassName.".java";
            $projectEntityKeyFile = $projectEntityFileDir."/".$curEntityClassName."Key.java";
            $javeEntityFile = $outputEntityFile;
            $javeEntityFile =~ s/$startDir/$javaProjectDir/g;

            # entity 是否有xxxKey 的父类, 表是联合主键
            $entityHaveBaseClass = 0;
            # 已经测试entity通过了,所以现在开始要默认设置为1, 这样就可以不必测试export entity了
            $entityHaveBaseClass = 1;

            $inputMapperFile = $srcDir."/".$originMapperDir."/".$curEntityClassName."Mapper.xml";
            $outputMapperFileDir = $startDir."/".$projectName."-base/src/main/resources/".$replacePackageDir."/entity/mapping";
            $outputMapperExtendFileDir = $outputMapperFileDir."/extend";
            $outputMapperFile = $outputMapperFileDir."/".$curEntityClassName."Mapper.xml";
            $projectMapperFileDir = $projectRootDir."/".$projectName."-base/src/main/resources/".$replacePackageDir."/entity/mapping";
            $projectMapperFile = $projectMapperFileDir."/".$curEntityClassName."Mapper.xml";
            # my $javeMapperFile = $javaProjectDir."/".$curEntityClassName.".java";
            $javeMapperFile = $outputMapperFile;
            $javeMapperFile =~ s/$startDir/$javaProjectDir/g;

            $javeMapperExtendFileDir = $outputMapperExtendFileDir;
            $javeMapperExtendFileDir =~ s/$startDir/$javaProjectDir/g;


            $inputDaoFile = $srcDir."/".$originDaoDir."/".$originDaoInterfaceName.".java";
            $outputDaoFileDir = $startDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao";
            $outputDaoFile = $outputDaoFileDir."/".$destDaoInterfaceName.".java";
            $outputDaoImplFileDir = $startDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao/impl";
            $outputDaoImplFile = $outputDaoImplFileDir."/".$curEntityClassName."DaoImpl.java";
            $projectDaoFileDir = $projectRootDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao";
            $projectDaoFile = $projectDaoFileDir."/".$destDaoInterfaceName.".java";
            $projectDaoImplFileDir = $projectRootDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao/impl";
            $projectDaoImplFile = $projectDaoImplFileDir."/".$curEntityClassName."DaoImpl.java";
            $javeDaoFile = $outputDaoFile;
            $javeDaoFile =~ s/$startDir/$javaProjectDir/g;


            $javeDaoImplFile = $outputDaoImplFile;
            $javeDaoImplFile =~ s/$startDir/$javaProjectDir/g;




            # print "处理表($curTableName)相关的entity, mapping, dao, daoImpl START\n";
            # print "curTableName:               $curTableName\n";
            # print "curEntityKeyClassName:      $curEntityKeyClassName\n";
            # print "curEntityClassName:         $curEntityClassName\n";
            # print "destMappingFileName:        $destMappingFileName\n";
            # print "destEntityPackage:          $destEntityPackage\n";
            # print "destDaoPackage:             $destDaoPackage\n";
            # print "destDaoImplPackage:         $destDaoImplPackage\n";
            # print "originDaoInterfaceName:     $originDaoInterfaceName\n";
            # print "destDaoInterfaceName:       $destDaoInterfaceName\n";
            # print "destDaoImplClassName:       $destDaoImplClassName\n";
            # print "destDaoImplRepositoryValue: $destDaoImplRepositoryValue\n";
            # print "\n\n\n";
            # print "srcDir:                      $srcDir\n";
            # print "startDir:                    $startDir\n";

            # print "inputEntityFile:             $inputEntityFile\n";
            # print "inputEntityKeyFile:          $inputEntityKeyFile\n";
            # print "outputEntityFileDir:         $outputEntityFileDir\n";
            # print "outputEntityFile:            $outputEntityFile\n";
            # print "outputEntityKeyFile:         $outputEntityKeyFile\n";
            # print "projectEntityFileDir:        $projectEntityFileDir\n";
            # print "projectEntityFile:           $projectEntityFile\n";
            # print "projectEntityKeyFile:        $projectEntityKeyFile\n";
            # print "javeEntityFile:              $javeEntityFile\n";
            # print "\n\n\n";
            # print "inputMapperFile:             $inputMapperFile\n";
            # print "outputMapperFileDir:         $outputMapperFileDir\n";
            # print "outputMapperExtendFileDir:   $outputMapperExtendFileDir\n";
            # print "outputMapperFile:            $outputMapperFile\n";
            # print "projectMapperFileDir:        $projectMapperFileDir\n";
            # print "projectMapperFile:           $projectMapperFile\n";
            # print "javeMapperFile:              $javeMapperFile\n";
            # print "javeMapperExtendFileDir:     $javeMapperExtendFileDir\n";
            # print "\n\n\n";
            # print "inputDaoFile:                $inputDaoFile\n";
            # print "outputDaoFileDir:            $outputDaoFileDir\n";
            # print "outputDaoFile:               $outputDaoFile\n";
            # print "outputDaoImplFileDir:        $outputDaoImplFileDir\n";
            # print "outputDaoImplFile:           $outputDaoImplFile\n";
            # print "javeDaoFile:                 $javeDaoFile\n";
            # print "javeDaoImplFile:             $javeDaoImplFile\n";




            # 处理entity文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理entity文件 START\n";
            exportEntityFile();
            print "处理entity文件 END\n";
            # 处理entity文件=====================END


            
            # 处理mapper文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理mapper文件 START\n";
            exportMapperFile();
            print "处理mapper文件 END\n";
            # 处理mapper文件=====================END
            
            
            
            # 处理dao&daoImpl文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理dao&daoImpl文件 START\n";
            exportDaoAndDaoImplFile();
            print "处理dao$daoImpl文件 END\n";
            # 处理dao&daoImpl文件=====================END


            print "处理表($curTableName)相关的entity, mapping, dao, daoImpl END\n";
            print "\n\n\n";
            
        }
        
    }
    close(GENERATORFILE);
}


# 删除generator.jar 自动生成的代码
rmtree('./src');



# 复制相关的目录到相关的文件中去


`pause`;

















