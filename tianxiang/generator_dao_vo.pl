#!/usr/bin/perl

# http://blog.csdn.net/p793049488/article/details/40422975

# 计划自动生成Vo和ExtendDaoImpl注释的脚本, 目前没有完成


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

my $isDoubleForeignKey = "0";

my $daoImplContent = "";



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
    my $tmpClassPropertyName = lc($curEntityClassName).".".lc($tmpPropertyName);
    my $tmpResult = $Config->{analysis}->{$tmpClassPropertyName};
    if (isDefaultPrimaryKey($tmpPropertyName)) {
        return "id";
    }
    if ($tmpResult eq "") {
        return $Config->{analysis}->{lc($tmpPropertyName)};
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
    return $tmpParam eq $primaryKeyId;
}

sub getDaoMethodComments {
    my $line = $_[0];
    my $newLine = "";
    my $size = @keywords;

    # 联合主键表的参数名称是: record 而非 id
    my $deleteByPrimaryKeyParamName = $isDoubleForeignKey ? "record" : $primaryKeyId;
    my @paramNames = ("", "", $deleteByPrimaryKeyParamName, "record", "record", $primaryKeyId, "record", "record", "condition");
    # 联合主键表的参数类型是: 当前类 而非 int
    my $deleteByPrimaryKeyParamType = $isDoubleForeignKey ? $curEntityClassName : "int";
    my @paramTypes = ("", "", $deleteByPrimaryKeyParamType, $curEntityClassName, $curEntityClassName, "int", $curEntityClassName, $curEntityClassName, "String");
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
            if ($paramType eq "int") {
                if (isDefaultPrimaryKey($paramName)) {  
                    $paramNameDesc = "id";
                } else {
                    $paramNameDesc = $Config->{analysis}->{$paramName};
                }

                $returnTypeDesc = $paramType;
                $seeParamTypeDesc = $paramType;
            } elsif ($paramType eq "String") {
                $paramNameDesc = "查询条件";
                $returnTypeDesc = "List<".$destEntityPackage.".".$curEntityClassName.">";
                $seeParamTypeDesc = $paramType;
            } else {
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
        if (!$isDoubleForeignKey) { # 只有在非联合主键的情况下使用
            my $addLine = "    List<".$curEntityClassName."> queryByCondition(String condition);\n";
            $newLine = getDaoMethodComments($addLine);
        }

        $daoImplContent .= "}\n";
    }

    # 联合主键生成的删除函数是:
    # int deleteByPrimaryKey(UserRoleKey key);
    # 要更换成: int deleteByPrimaryKey(UserRoleKey record);
    if ($line =~ /deleteByPrimaryKey\(([^"]+) ([^"]+)\);/ && $isDoubleForeignKey) {
        my $matchParamName = $2;
        $line =~ s/$matchParamName/record/g;
    }
    $newLine .= $line;

    return $newLine;
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

            my $headerName = $curEntityClassName;
            # 首字母变小写
            $headerName =~ s/\b\w/\l$&/g;

            my $configInfo = $Config->{package}->{$curTableName};
            my @configItems = split(/\|/, $configInfo);
            my $replacePackage = $configItems[0];
            my $replacePackageDir = $replacePackage;
            $replacePackageDir =~ s/\./\//g;
            
            $isDoubleForeignKey = $configItems[1];

            $destMappingFileName = $curEntityClassName."Mapper";
            $destEntityPackage = $replacePackage.".entity";
            $destDaoPackage = $replacePackage.".dao";
            $destDaoImplPackage = $replacePackage.".dao.impl";
            $originDaoInterfaceName = "I".$curEntityClassName."Dao";
            $destDaoInterfaceName = $curEntityClassName."Dao";
            $destDaoImplClassName = $destDaoInterfaceName."Impl";
            $destDaoImplRepositoryValue = $headerName."Dao";
            $primaryKeyId = $headerName."Id";

            my $srcDir = "./src";
            my $startDir = "./".$resultCodeDirName;

            my $inputEntityFile = $srcDir."/".$originEntityDir."/".$curEntityClassName.".java";
            my $outputEntityFileDir = $startDir."/".$projectName."-base/src/main/java/".$replacePackageDir."/entity";
            my $outputEntityFile = $outputEntityFileDir."/".$curEntityClassName.".java";
            my $projectEntityFileDir = $projectRootDir."/".$projectName."-base/src/main/java/".$replacePackageDir."/entity";
            my $projectEntityFile = $projectEntityFileDir."/".$curEntityClassName.".java";
            my $javeEntityFile = $outputEntityFile;
            $javeEntityFile =~ s/$startDir/$javaProjectDir/g;

            my $inputMapperFile = $srcDir."/".$originMapperDir."/".$curEntityClassName."Mapper.xml";
            my $outputMapperFileDir = $startDir."/".$projectName."-base/src/main/resources/".$replacePackageDir."/entity/mapping";
            my $outputMapperExtendFileDir = $outputMapperFileDir."/extend";
            my $outputMapperFile = $outputMapperFileDir."/".$curEntityClassName."Mapper.xml";
            my $projectMapperFileDir = $projectRootDir."/".$projectName."-base/src/main/resources/".$replacePackageDir."/entity/mapping";
            my $projectMapperFile = $projectMapperFileDir."/".$curEntityClassName."Mapper.xml";
            # my $javeMapperFile = $javaProjectDir."/".$curEntityClassName.".java";
            my $javeMapperFile = $outputMapperFile;
            $javeMapperFile =~ s/$startDir/$javaProjectDir/g;

            my $javeMapperExtendFileDir = $outputMapperExtendFileDir;
            $javeMapperExtendFileDir =~ s/$startDir/$javaProjectDir/g;


            my $inputDaoFile = $srcDir."/".$originDaoDir."/".$originDaoInterfaceName.".java";
            my $outputDaoFileDir = $startDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao";
            my $outputDaoFile = $outputDaoFileDir."/".$destDaoInterfaceName.".java";
            my $outputDaoImplFileDir = $startDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao/impl";
            my $outputDaoImplFile = $outputDaoImplFileDir."/".$curEntityClassName."DaoImpl.java";
            my $projectDaoFileDir = $projectRootDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao";
            my $projectDaoFile = $projectDaoFileDir."/".$destDaoInterfaceName.".java";
            my $projectDaoImplFileDir = $projectRootDir."/".$projectName."-".$curModule."/src/main/java/".$replacePackageDir."/dao/impl";
            my $projectDaoImplFile = $projectDaoImplFileDir."/".$curEntityClassName."DaoImpl.java";
            my $javeDaoFile = $outputDaoFile;
            $javeDaoFile =~ s/$startDir/$javaProjectDir/g;


            my $javeDaoImplFile = $outputDaoImplFile;
            $javeDaoImplFile =~ s/$startDir/$javaProjectDir/g;



            if ($isDoubleForeignKey) {
                $curEntityClassName = $curEntityClassName."Key";
                # class name 已经变化了
                $inputEntityFile = "./src/".$originEntityDir."/".$curEntityClassName.".java";
                $outputEntityFile = $outputEntityFileDir."/".$curEntityClassName.".java";
            }


            print "处理表($curTableName)相关的entity, mapping, dao, daoImpl START\n";
            print "curTableName:               $curTableName\n";
            print "curEntityClassName:         $curEntityClassName\n";
            print "isDoubleForeignKey:         $isDoubleForeignKey\n";
            print "destMappingFileName:        $destMappingFileName\n";
            print "destEntityPackage:          $destEntityPackage\n";
            print "destDaoPackage:             $destDaoPackage\n";
            print "destDaoImplPackage:         $destDaoImplPackage\n";
            print "originDaoInterfaceName:     $originDaoInterfaceName\n";
            print "destDaoInterfaceName:       $destDaoInterfaceName\n";
            print "destDaoImplClassName:       $destDaoImplClassName\n";
            print "destDaoImplRepositoryValue: $destDaoImplRepositoryValue\n";
            print "\n\n\n";
            print "srcDir:                      $srcDir\n";
            print "startDir:                    $startDir\n";

            print "inputEntityFile:             $inputEntityFile\n";
            print "outputEntityFileDir:         $outputEntityFileDir\n";
            print "outputEntityFile:            $outputEntityFile\n";
            print "projectEntityFileDir:        $projectEntityFileDir\n";
            print "projectEntityFile:           $projectEntityFile\n";
            print "javeEntityFile:              $javeEntityFile\n";
            print "\n\n\n";
            print "inputMapperFile:             $inputMapperFile\n";
            print "outputMapperFileDir:         $outputMapperFileDir\n";
            print "outputMapperExtendFileDir:   $outputMapperExtendFileDir\n";
            print "outputMapperFile:            $outputMapperFile\n";
            print "projectMapperFileDir:        $projectMapperFileDir\n";
            print "projectMapperFile:           $projectMapperFile\n";
            print "javeMapperFile:              $javeMapperFile\n";
            print "javeMapperExtendFileDir:     $javeMapperExtendFileDir\n";
            print "\n\n\n";
            print "inputDaoFile:                $inputDaoFile\n";
            print "outputDaoFileDir:            $outputDaoFileDir\n";
            print "outputDaoFile:               $outputDaoFile\n";
            print "outputDaoImplFileDir:        $outputDaoImplFileDir\n";
            print "outputDaoImplFile:           $outputDaoImplFile\n";
            print "javeDaoFile:                 $javeDaoFile\n";
            print "javeDaoImplFile:             $javeDaoImplFile\n";




            #处理entity文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理entity文件 START\n";
            my $entityCode = "";
            if (open(ENTITYFILE, $inputEntityFile)) {
                while ($line = <ENTITYFILE>) {
                    my $newLine = "";
                    #处理package包路径，将generator生成的包路径，替换为工程结构的包路径
                    if ($line =~ /package.$originEntityPackage/) { # 包名
                        $newLine = "package ".$destEntityPackage.";\n";
                    } elsif ($line =~ /public class /) { # 类注释
                        $newLine .= "/**\n";
                        $newLine .= " *\n";
                        $newLine .= " * \@Project : ".$projectName."\n";
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
            
            print "处理entity文件 END\n";
            #处理entity文件=====================END


            
            #处理mapper文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理mapper文件 START\n";
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
                
                #不存在queryByCondition方法时的处理
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
                $xmlCode =~ s/$oldType/$newType/g;
                
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
            print "处理mapper文件 END\n";
            #处理mapper文件=====================END
            
            
            
            #处理dao&daoImpl文件=====================START
            print "-----------------------------------------------------------------------------\n";
            print "处理dao&daoImpl文件 START\n";
            #根据generator生成的IDao接口生成实现
            my $idaoCode = "";
            print "inputDaoFile:  $inputDaoFile\n";

            #读取接口文件获取主键类型
            if (open(DAOFILE, $inputDaoFile)) {
                # 开始处理dao文件的时候,先把daoImplContent置空
                $daoImplContent = "";
                while($line = <DAOFILE>) {
                    my $newLine = "";
                    if ($line =~ /package /) {
                        $newLine .= "package ".$destDaoPackage.";\n";

                        # dao impl
                        $daoImplContent .= "package ".$destDaoImplPackage.";\n";
                        $daoImplContent .= "\n";

                    } elsif ($line =~ /import/) {
                        $newLine .= "import ".$destEntityPackage.".".$curEntityClassName.";\n";
                        # 在非联合主键的时候,才有这个import
                        if (!$isDoubleForeignKey) {
                            $newLine .= "import java.util.List;\n";
                        }

                        # dao impl
                        if (!$isDoubleForeignKey) {
                            $daoImplContent .= "import java.util.List;\n";
                        }
                        $daoImplContent .= "import org.springframework.stereotype.Repository;\n";
                        $daoImplContent .= "import com.yicoding.common.base.MyBatisDao;\n";
                        $daoImplContent .= "import ".$destEntityPackage.".".$curEntityClassName.";\n";
                        $daoImplContent .= "import ".$destDaoPackage.".".$destDaoInterfaceName.";\n";

                    } elsif ($line =~ /public interface/) {
                        $newLine .= "/**\n";
                        $newLine .= " *\n";
                        $newLine .= " * \@Project : ".$projectName."\n";
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
                        $daoImplContent .= " * \@Project : ".$projectName."\n";
                        $daoImplContent .= " * \@Package : ".$destDaoImplPackage."\n";
                        $daoImplContent .= " * \@Class : ".$destDaoInterfaceName."\n";
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
                    }
                    # print "输出Line   :".$line;
                    # print "输出newLine:".$newLine;
                    $idaoCode .= $newLine;
                }
                close(DAOFILE);

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
            print "处理dao$daoImpl文件 END\n";
            #处理dao&daoImpl文件=====================END


            print "处理表($curTableName)相关的entity, mapping, dao, daoImpl END\n";
            print "\n\n\n";
            
        }
        
    }
    close(GENERATORFILE);
}


#删除generator.jar 自动生成的代码
rmtree('./src');



# 复制相关的目录到相关的文件中去


`pause`;

















