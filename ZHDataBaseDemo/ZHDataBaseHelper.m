//
//  ZHDataBaseHelper.m
//  iOSDataBaseSample
//
//  Created by 钟振华 on 2017/9/11.
//  Copyright © 2017年 Xinzhili. All rights reserved.
//

#import "ZHDataBaseHelper.h"
#import "FMDB.h"
#import "ZHUniversalDBDataModel.h"
NSString *const APP_USER_DB  = @"APP_USER_DB";

static NSString *const updateId = @"id";
static NSString *const updateObject = @"json";
static NSString *const updateJsonClassName = @"jsonClassName";
static NSString *const updateCreatedTime = @"createdTime";
static NSString *const updateType = @"type";
static NSString *const updatePosition = @"position";
static NSString *const updateText1  = @"text1";
static NSString *const updateText2  = @"text2";
static NSString *const updateText3  = @"text3";

/** 创建一个可以存储json字符串的通用型表的SQL */
static NSString *const CREATE_A_UNIVERSAL_DATA_STORE_TABLE_SQL =
@"CREATE TABLE IF NOT EXISTS %@ ( \
id TEXT NOT NULL PRIMARY KEY UNIQUE ON CONFLICT REPLACE, \
json TEXT , \
jsonClassName TEXT , \
createdTime TEXT NOT NULL, \
type TEXT, \
position TEXT NOT NULL, \
text1 TEXT, \
text2 TEXT, \
text3 TEXT)";

/** 插入 (直接覆盖)一个通用型数据 */
static NSString *const INSERT_A_UNIVERSAL_DATA_SQL =
@"REPLACE INTO %@ \
(id, \
json, \
jsonClassName, \
createdTime, \
type, \
position, \
text1, \
text2, \
text3) \
values (?,?,?,?,?,?,?,?,?)";

/** 按照条件删除 */
static NSString *const DELETE_UNIVERSAL_ITEMS_CONDITION_SQL =
@"DELETE from %@ where %@";
/** 删除一个 */
static NSString *const DELETE_UNIVERSAL_ITEM_SQL =
@"DELETE from %@ where id = ?";
/** 删除时间最早的一条数据 */
static NSString *const DELETE_LAST_UNIVERSAL_ITEM_SQL =
@"DELETE from %@ where id = (select id from %@ order by createdTime) ";
/** 删除一组 */
static NSString *const DELETE_UNIVERSAL_ITEMS_SQL =
@"DELETE from %@ where id in ( %@ )";
/** 清空表 */
static NSString *const CLEAN_ALL_UNIVERSA_TABLE_SQL =
@"DELETE from %@";

/** 修改和更新 */
static NSString *const UPDATE_ONE_UNIVERSA_ITEM_CONDITON_SQL =
@"UPDATE %@ set %@ = ? WHERE id = ?";

/** 查询 */
static NSString *const SELECT_WITH_SEARCH_CONDITION_SQL = @"SELECT * from ";
/** 统计和条件 **/
static NSString *const SELECT_ID_DEFINED_COUNT_SQL =
@"SELECT count(id) as count from %@";
/** 拼接时间的sql */
static NSString *const SELECT_MOSAIC_TIME_SQL =
@"order by createdTime desc, position  desc";
/** 拼接降序sql */
static NSString *const ORDER_BY_DESC = @"order by %@ desc";

/** 升序排列 */
NSString *const SORT_ASC = @"ASC";
/** 降序排列 */
NSString *const SORT_DESC = @"DESC";


@interface ZHDataBaseHelper ()

@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
@property(nonatomic, strong) NSRecursiveLock *threadLock;

@end
@implementation ZHDataBaseHelper
ZHSingletonImplementation(ZHDataBaseHelper)

#pragma mark -- > 初始化操作
- (instancetype)init {
    
    if (self = [super init]) {
        
        self.threadLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (NSString *)openDataBaseWithUserName:(NSString *)userName {
    
    if (userName.length == 0) {
        return nil;
    }
    // 1.library
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    // 2.生成数据库所在文件夹
    NSString *documentsDirectory = [[paths firstObject] stringByAppendingString:userName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = FALSE;
    BOOL isDirectoryExist = [fileManager fileExistsAtPath:documentsDirectory isDirectory:&isDirectory];
    if (!(isDirectory && isDirectoryExist)) {
        BOOL createDir = [fileManager createDirectoryAtPath:documentsDirectory
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
        if (!createDir) {
            NSLog(@"Create Database Directory Failed.");
        }
    }
    // 3.数据库完整路径，并初始化数据库
    NSString *dbPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db",userName]];
    NSLog(@"【用户数据库路径】：%@", dbPath);
    if (_dbQueue) {
        
        [self close];
    }
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    
    return documentsDirectory;
}

- (void)close {
    
    [_dbQueue close];
    _dbQueue = nil;
}
#pragma mark --> 创建 清空一个表
// 创建一个表
- (void)createCustomTableWithName:(NSString *)tableName {
    
    [self _createTable:tableName sql:[NSString stringWithFormat:CREATE_A_UNIVERSAL_DATA_STORE_TABLE_SQL,tableName]];
}


// 清空一个表
- (void)cleanTable:(NSString *)tableName {
    
    if ([self _isValidTableName:tableName] == NO) {
        return;
    }
    NSString *sql = [NSString stringWithFormat:CLEAN_ALL_UNIVERSA_TABLE_SQL, tableName];
    __block BOOL result;
    [self _executeDB:^(FMDatabase *db) {
        
        result = [db executeUpdate:sql];
    }];
    
    if (!result) {
        
        NSLog(@"ERROR,清除表 出错 clear table: %@", tableName);
    }
}

#pragma mark - -> 数据库CRUD操作API

#pragma mark - --> 1、增加和插入数据

/**
 插入一条通用性数据到某张表

 @param universalData 通用性数据模型
 @param tableName 表名
 */
- (BOOL)insertUniversalDataModel:(ZHUniversalDBDataModel *)universalData toTable:(NSString *)tableName {
    
    return [self insertUniversalDataWithId:universalData.itemId
                                   jsonStr:universalData.json
                             jsonClassName:universalData.jsonClassName
                               createdTime:universalData.createdTime
                                      type:universalData.type
                                  position:universalData.position
                                     text1:universalData.text1
                                     text2:universalData.text2
                                     text3:universalData.text3
                                  maxCount:0
                                 intoTable:tableName];
}
/** 插入一条通用型数据到存储表中 */
- (BOOL)insertUniversalDataWithId:(NSString *)dataId
                          jsonStr:(NSString *)jsonStr
                    jsonClassName:(NSString *)className
                      createdTime:(NSString *)createdTime
                             type:(NSString *)type
                         position:(NSString *)position
                            text1:(NSString *)text1
                            text2:(NSString *)text2
                            text3:(NSString *)text3
                         maxCount:(int)maxCount
                        intoTable:(NSString *)tableName {
    
    if (dataId == nil) {
        return NO;
    }
    if (!tableName || tableName.length == 0) {
        return NO;
    }
    if (maxCount) {
        // 将数据库最早的数据删掉
        NSString *deleteLastObjSql = [NSString stringWithFormat:DELETE_LAST_UNIVERSAL_ITEM_SQL,tableName,tableName];
        __block BOOL result;
        [self _executeDB:^(FMDatabase *db) {
            result = [db executeUpdate:deleteLastObjSql];
        }];
        
        if (!result) {
            
            NSLog(@"ERROR, 删除数据库最早的数据时出错 from table: %@",
                  tableName);
        }
    }
    if (createdTime && createdTime.length == 0) {
        
    } else {
        
    }
    NSString *insertSql = [NSString stringWithFormat:INSERT_A_UNIVERSAL_DATA_SQL,tableName];
    __block BOOL result;
    [self _executeDB:^(FMDatabase *db) {
        result = [db executeUpdate:insertSql,dataId,jsonStr,className,createdTime,type,position,text1,text2,text3];
    }];
    if (!result) {
        
        NSLog(@"ERROR, 插入数据 出错 into table: %@", tableName);
    }
    return result;
}

#pragma mark - --> 2、删除数据

/**
 通过条件删除数据

 @param condition 删除条件
 @param tableName 表名
 @return 返回值
 */
- (BOOL)deleteUniversalDataByCondition:(NSString *)condition fromTable:(NSString *)tableName {
    
    if (!condition || condition.length == 0) {
        return NO;
    }
    if ([self _isValidTableName:tableName] == NO) {
        return NO;
    }
    NSString *deleteConditionsql =
    [NSString stringWithFormat:DELETE_UNIVERSAL_ITEMS_CONDITION_SQL,tableName, condition];
    __block BOOL result;
    [self _executeDB:^(FMDatabase *db) {
        
        result = [db executeUpdate:deleteConditionsql];
    }];
    
    if (!result) {
        
        NSLog(@"ERROR, 删除数据时出错 table: %@", tableName);
        NSLog(@"%@", [NSString stringWithFormat:@"您已引发bug 出错 : %@", condition]);
    }
    
    return result;
}

/**
 删除一条数据

 @param dataId 主键
 @param tableName 表名
 @return 返回值
 */
- (BOOL)deleteUniversalDataById:(NSString *)dataId fromTable:(NSString *)tableName {
    if ([self _isValidTableName:tableName] == NO) {
        
        return NO;
    }
    NSString *sql = [NSString stringWithFormat:DELETE_UNIVERSAL_ITEM_SQL, tableName];
    NSLog(@"\n -----===SQL执行===----- \n%@",sql);
    __block BOOL result;
    [self _executeDB:^(FMDatabase *db) {
        
        result = [db executeUpdate:sql, dataId];
    }];
    
    if (!result) {
        
        NSLog(@"ERROR, 删除某一条数据时出错 table: %@", tableName);
        NSLog(@"%@", [NSString stringWithFormat:@"您已引发bug 出错 : %@", dataId]);
    } else {
        
        NSLog(@"Info :成功删除一条数据 id: %@", dataId);
    }
    
    return result;
}

/**
 删除一组数据

 @param dataIdsArray 主键数组
 @param tableName 表名
 @return 返回值
 */
- (BOOL)deleteUniversalDatasByIds:(NSArray *)dataIdsArray
                        fromTable:(NSString *)tableName {
    
    if ([self _isValidTableName:tableName] == NO) {
        
        return NO;
    }
    NSMutableString *stringBuilder = [NSMutableString string];
    
    for (id objectId in dataIdsArray) {
        
        NSString *item = [NSString stringWithFormat:@" '%@' ", objectId];
        
        if (stringBuilder.length == 0) {
            
            [stringBuilder appendString:item];
        } else {
            
            [stringBuilder appendString:@","];
            [stringBuilder appendString:item];
        }
    }
    
    NSString *sql =
    [NSString stringWithFormat:DELETE_UNIVERSAL_ITEMS_SQL, tableName, stringBuilder];
    NSLog(@"\n -----===SQL执行===----- \n%@",sql);
    
    __block BOOL result;
    
    [self _executeDB:^(FMDatabase *db) {
        
        result = [db executeUpdate:sql];
    }];
    
    if (!result) {
        
        NSLog(@"ERROR, 群删 数据时出错 from table: %@", tableName);
    }
    return result;
}

#pragma mark --> 3、更改和更新数据

/**
 更新一条数据到目标表里
 
 @param universalDataModel 通用数据模型
 @param tableName 表名称
 @return 是否成功
 */

- (BOOL)updateUniversalData:(ZHUniversalDBDataModel *)universalDataModel intoTable:(NSString *)tableName {
    if (universalDataModel.itemId && universalDataModel.itemId.length > 0) {
    } else {
        
        NSLog(@"ERROR：更新失败，通用数据模型id非法");
        return NO;
    }
    
    NSString *itemId = universalDataModel.itemId;
    if (universalDataModel.json && universalDataModel.json > 0) {
        [self updateOneFieldDataWithDataId:itemId
                               updateField:updateObject
                                 updateObj:universalDataModel.json
                                 intoTable:tableName];
    }
    if (universalDataModel.jsonClassName && universalDataModel.jsonClassName.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateJsonClassName
                                updateObj:universalDataModel.jsonClassName
                                 intoTable:tableName];
    }
    
    if (universalDataModel.createdTime && universalDataModel.createdTime.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateCreatedTime
                                updateObj:universalDataModel.createdTime
                                 intoTable:tableName];
    }
    
    if (universalDataModel.type && universalDataModel.type.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateType
                                updateObj:universalDataModel.type
                                 intoTable:tableName];
    }
    
    if (universalDataModel.position && universalDataModel.position.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updatePosition
                                updateObj:universalDataModel.position
                                 intoTable:tableName];
    }
    
    if (universalDataModel.text1 && universalDataModel.text1.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateText1
                                updateObj:universalDataModel.text1
                                 intoTable:tableName];
    }
    
    if (universalDataModel.text2 && universalDataModel.text2.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateText2
                                updateObj:universalDataModel.text2
                                 intoTable:tableName];
    }
    
    if (universalDataModel.text3 && universalDataModel.text3.length > 0) {
        
        [self updateOneFieldDataWithDataId:itemId
                              updateField:updateText3
                                updateObj:universalDataModel.text3
                                 intoTable:tableName];
    }

    return YES;
}

/**
 更新目标主键对应的某一个字段的数据

 @param dataId 主键id
 @param targetField 字段
 @param object 新传入的数据
 @param tableName 表名称
 @return 返回值
 */
- (BOOL)updateOneFieldDataWithDataId:(NSString *)dataId
                   updateField:(NSString *)targetField
                     updateObj:(id)object
                           intoTable:(NSString *)tableName {
    if (dataId == nil || object == nil || targetField == nil ||
        [targetField isEqualToString:updatePosition] ||
        [targetField isEqualToString:updateId]) {
        
        NSLog(@"非法参数传入->更新操作失败");
        return NO;
    }
    
    if ([self _isValidTableName:tableName] == NO) {
        
        NSLog(@"非法表名称传入->更新操作失败");
        return NO;
    }
    
    id updatedObj;
    if ([object isKindOfClass:[NSString class]]) {
        
        updatedObj = object;
    }
    
    NSString *sql =
    [NSString stringWithFormat:UPDATE_ONE_UNIVERSA_ITEM_CONDITON_SQL, tableName, targetField];
    NSLog(@"\n -----===SQL执行===----- \n%@",sql);
    
    __block BOOL result;
    [self _executeDB:^(FMDatabase *db) {
        
        result = [db executeUpdate:sql, updatedObj, dataId];
    }];
    
    if (!result) {
        
        NSLog(@"ERROR, 没有更新 table: %@  condition : %@  obj :%@ ",tableName, targetField, object);
    } else {
        
        NSLog(@" 更新成功 table: %@  condition : %@  obj :%@ ",
              tableName,
              targetField, object);
    }
    
    return result;
}

#pragma mark --> 4、查找数据
/**
 *  根据某条id  查询某条数据  (返回的是ZHUniversalDBDataModel 模型)
 */
- (ZHUniversalDBDataModel *)searchOneUniversalDataModelById:(NSString *)itemId fromTable:(NSString *)tableName {
    NSArray *array =
    [self searchUniversalDataModelWithSearchCondition:[NSString stringWithFormat:@"%@ = '%@'",updateId, itemId]
                                          searchCount:1
                                            fromTable:tableName];
    if (array && array.count > 0) {
        
        return [array lastObject];
    }
    
    return nil;
}

- (NSArray *)searchUniversalDataModelWithSearchCondition:(NSString *)searchCondition searchCount:(int)searchCount fromTable:(NSString *)tableName {
    
    if ([self _isValidTableName:tableName]) {
        return nil;
    }
    NSString *sql;
    if (searchCondition) {
        sql = [NSString stringWithFormat:@"%@ %@ where %@ %@",SELECT_WITH_SEARCH_CONDITION_SQL,tableName,searchCondition,SELECT_MOSAIC_TIME_SQL];
    } else {
        sql = [NSString stringWithFormat:@"%@ %@ %@",SELECT_WITH_SEARCH_CONDITION_SQL,tableName,SELECT_MOSAIC_TIME_SQL];
    }
    
    if (searchCount) {
        sql = [NSString stringWithFormat:@"%@ Limit %d",sql, searchCount];
    }
    return [self searchUniversalDataModelsWithSQL:sql fromTableName:tableName];
}

- (NSArray *)searchUniversalDataModelsWithSQL:(NSString *)sql fromTableName:(NSString *)tableName {
    
    __block NSMutableArray *result = [NSMutableArray array];
    [self _executeDB:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            ZHUniversalDBDataModel *mode = [[ZHUniversalDBDataModel alloc] init];
            mode.itemId = [rs stringForColumn:updateId];
            mode.json = [rs stringForColumn:updateObject];
            mode.jsonClassName = [rs stringForColumn:updateJsonClassName];
            mode.createdTime = [rs stringForColumn:updateCreatedTime];
            mode.type = [rs stringForColumn:updateType];
            mode.position = [rs stringForColumn:updatePosition];
            mode.text1 = [rs stringForColumn:updateText1];
            mode.text2 = [rs stringForColumn:updateText2];
            mode.text3 = [rs stringForColumn:updateText3];
            [result addObject:mode];
        }
        [rs close];
    }];
    return result;
}

/**
 查询出所有的通用型数据

 @param tableName 表名称
 @return ZHUniversalDBDataModel数组
 */
- (NSArray *)searchAllUniversalDataModelFromTable:(NSString *)tableName {
    
    NSString *sql = [NSString stringWithFormat:@"%@%@",SELECT_WITH_SEARCH_CONDITION_SQL,tableName];
    return [self searchUniversalDataModelsWithSQL:sql fromTableName:tableName];
}

/**
 清空表

 @param tableName 表名称
 @return YES NO
 */
- (BOOL)cleanAllDataForTable:(NSString *)tableName {
    
    __block NSString *sql = [NSString stringWithFormat:
                             CLEAN_ALL_UNIVERSA_TABLE_SQL,
                             tableName];
    
    __block BOOL ret = NO;
    [self _executeDB:^(FMDatabase *db) {
        
        ret = [db executeUpdate:sql];
    }];
    
    return ret;
}

#pragma mark --> 私有方法
// 创建表
- (BOOL)_createTable:(NSString *)tableName
                 sql:(NSString *)createSql {
    
    if ([self _isValidTableName:tableName] == NO) {
        NSLog(@"表名称非法");
        return NO;
    }
    NSString *create_table_sql = createSql;
    NSLog(@"\n -----===SQL执行===----- \n%@",createSql);
    
    __block BOOL result = NO;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
        if (![db tableExists:tableName]) {
            
            result = [db executeUpdate:create_table_sql];
            
            if (!result) {
                
                NSLog(@"ERROR, 创表 出错 create table: %@", tableName);
            }
        }
    }];
    return result;
}


// 是否存在表
- (BOOL)_isExistTableName:(NSString *)tableName {
    
    if (!(tableName && tableName.length > 0)) {
        return NO;
    }
    __block BOOL result = NO;
    __block NSString *chatTableName = tableName;
    [self _executeDB:^(FMDatabase *db) {
        result = [db tableExists:chatTableName];
    }];
    return result;
}

- (BOOL)_isValidTableName:(NSString *)tableName {
    
    if (tableName == nil || tableName.length == 0 || [tableName rangeOfString:@" "].location != NSNotFound) {
        NSLog(@"数据库判断 表名是否合格出错, table name: %@ format error.", tableName);
        return NO;
    }
    return YES;
}

/**
 获取要执行数据库的DB
 */
- (void)_executeDB:(void(^)(FMDatabase *db))block {
    
    [_threadLock lock];
    if (_dbQueue == nil) {
        
        [self openDataBaseWithUserName:APP_USER_DB];
    }
    [_dbQueue inDatabase:^(FMDatabase *db) {
        block(db);
    }];
    [_threadLock unlock];
}


/**
 执行插入SQL
 */
- (BOOL)_executeInsertSQL:(NSString *)insertSql
                andValues:(NSArray *)values {
    
    __block BOOL ret = NO;
    
    NSLog(@"执行insert sql：%@",insertSql);
    [self _executeDB:^(FMDatabase *db) {
        
        ret = [db executeUpdate:insertSql withArgumentsInArray:values];
    }];
    
    return ret;
}

- (BOOL)_executeInsertSQL:(NSString *)insertSql
  withParameterDictionary:(NSDictionary *)valueDic {
    
    __block BOOL ret = NO;
    
    NSLog(@"执行insert sql：%@",insertSql);
    [self _executeDB:^(FMDatabase *db) {
        
        ret = [db executeUpdate:insertSql withParameterDictionary:valueDic];
    }];
    
    return ret;
}

/**
 执行删除SQL
 */
- (BOOL)_executeDeleteSQL:(NSString *)deleteSql {
    
    __block BOOL ret = NO;
    
    NSLog(@"执行Delete sql：%@",deleteSql);
    
    [self _executeDB:^(FMDatabase *db) {
        
        ret = [db executeUpdate:deleteSql];
    }];
    
    return ret;
}


/**
 执行更新SQL
 */
- (BOOL)_executeUpdateSQL:(NSString *)updateSql {
    
    __block BOOL ret = NO;
    NSLog(@"执行updateSql sql：%@",updateSql);
    
    [self _executeDB:^(FMDatabase *db) {
        
        ret = [db executeUpdate:updateSql];
    }];
    
    return ret;
}

/**
 执行查询SQL
 */
- (BOOL)_executeSearchSQL:(NSString *)searchSql {
    
    __block BOOL ret = NO;
    NSLog(@"执行searchSql sql：%@",searchSql);
    
    [self _executeDB:^(FMDatabase *db) {
        
        FMResultSet *rs = [db executeQuery:searchSql];
        while ([rs next]) {
            
        }
        [rs close];
    }];
    
    return ret;
}


@end
