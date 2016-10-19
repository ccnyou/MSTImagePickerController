//
//  MSTPhotoManager.m
//  MSTImagePickerController
//
//  Created by Mustard on 2016/10/9.
//  Copyright © 2016年 Mustard. All rights reserved.
//

#import "MSTPhotoManager.h"
#import "UIImage+MSTUtiles.h"
#import "MSTAlbumModel.h"

@interface MSTPhotoManager ()
@property (strong, nonatomic) PHCachingImageManager *cacheImageManager;
@end

@implementation MSTPhotoManager

+ (instancetype)sharedInstance{
    static MSTPhotoManager *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MSTPhotoManager alloc] init];
    });
    
    return instance;
}

- (void)loadCameraRollInfoisDesc:(BOOL)isDesc isOnlyShowImage:(BOOL)isOnlyShowImage CompletionBlock:(void (^)(MSTAlbumModel *))completionBlock {
    PHFetchResult *albumCollection= [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    
    [albumCollection enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:!isDesc]];
        if (isOnlyShowImage) {
            fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d",PHAssetMediaTypeImage];
        }
        
        PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:obj options:fetchOptions];
        
        MSTAlbumModel *model = [[MSTAlbumModel alloc] init];
        model.albumName = obj.localizedTitle;
        model.content = result;
        
        completionBlock ? completionBlock(model) : nil;
    }];
}

- (void)loadAlbumInfoIsShowEmpty:(BOOL)isShowEmpty isDesc:(BOOL)isDesc isOnlyShowImage:(BOOL)isOnlyShowImage CompletionBlock:(void (^)(NSArray *))completionBlock {
    //用来存放每个相册的model
    NSMutableArray *albumModelsArray = [NSMutableArray array];
    
    //1.获取所有相册的信息PHFetchResult<PHAssetCollection *>
    PHFetchResult *albumsCollection1 = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    
    //创建读取相册信息的options
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:!isDesc]];
    if (isOnlyShowImage) {
        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d",PHAssetMediaTypeImage];
    }
    
    //2.遍历albumsCollection获取每一个相册的具体信息
    [albumsCollection1 enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        //读取相册里面的所有信息 PHFetchResult<PHAsset *>
        PHFetchResult *assetsResult = [PHAsset fetchAssetsInAssetCollection:obj options:fetchOptions];
        
        if (assetsResult.count > 0 || isShowEmpty) {
            //创建一个model封装这个相册的信息
            MSTAlbumModel *model = [[MSTAlbumModel alloc] init];
            model.albumName = obj.localizedTitle;//相册名
            model.content = assetsResult;//保存这个相册的内容
            
            [albumModelsArray addObject:model];
        }
        
    }];
    
    PHFetchResult *albumsCollection2 = [PHAssetCollection fetchTopLevelUserCollectionsWithOptions:nil];
    
    [albumsCollection2 enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL * _Nonnull stop) {

        //读取相册里面的所有信息 PHFetchResult<PHAsset *>
        PHFetchResult *assetsResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
        
        if (assetsResult.count > 0 || isShowEmpty) {
            //创建一个model封装这个相册的信息
            MSTAlbumModel *model = [[MSTAlbumModel alloc] init];
            model.albumName = collection.localizedTitle;//相册名
            model.content = assetsResult;//保存这个相册的内容
            
            [albumModelsArray addObject:model];
        }
        
    }];
    
    //回调
    completionBlock ? completionBlock(albumModelsArray) : nil;
}

- (NSArray<MSTMoment *> *)sortByMomentType:(MSTImageMomentGroupType)momentType assets:(PHFetchResult *)fetchResult {
    MSTMoment *newMoment = nil;
    
    NSMutableArray *groups = [NSMutableArray array];
    
    for (NSInteger i = 0; i < fetchResult.count; i++) {
        PHAsset *asset = fetchResult[i];
        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday fromDate:asset.creationDate];
        
        NSUInteger year = components.year;
        NSUInteger month = components.month;
        NSUInteger day = components.day;
        
        switch (momentType) {
            case MSTImageMomentGroupTypeYear:
                if (newMoment && newMoment.dateComponents.year == year) break;
            case MSTImageMomentGroupTypeMonth:
                if (newMoment && newMoment.dateComponents.year == year && newMoment.dateComponents.month == month) break;
            case MSTImageMomentGroupTypeDay:
                if (newMoment && newMoment.dateComponents.year == year && newMoment.dateComponents.month == month && newMoment.dateComponents.day == day) break;
            default:
                newMoment = [MSTMoment new];
                newMoment.dateComponents = components;
                newMoment.date = asset.creationDate;
                [groups addObject:newMoment];
                break;
        }
        [newMoment.assets addObject:asset];
    }
    return groups;
}

#pragma mark -
- (void)getThumbnailImageFromPHAsset:(PHAsset *)asset completionBlock:(void (^)(UIImage *))completionBlock{
    //创建异步读取图片的options
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    options.synchronous = YES;
    
    CGFloat scale = [UIScreen mainScreen].scale;
    [self.cacheImageManager requestImageForAsset:asset targetSize:CGSizeMake(70*scale, 70*scale) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        result = [UIImage fixOrientation:result];
        result = [result resizeImageWithNewSize:[UIImage retriveScaleDstSize:result.size]];
        //回调读取的图片
        completionBlock ? completionBlock(result) : nil;
    }];
}

- (void)getPreviewImageFromPHAsset:(PHAsset *)asset photoWidth:(CGFloat)photoWidth comletionBlock:(void (^)(UIImage *, NSDictionary *))completionBlock {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    CGFloat aspectRatio = asset.pixelWidth / asset.pixelHeight;
    CGFloat pixelWidth = photoWidth * scale;
    CGFloat pixelHeight = photoWidth / aspectRatio;
    CGSize imageSize = CGSizeMake(pixelWidth, pixelHeight);
    
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    options.synchronous = NO;
    
    [self.cacheImageManager requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        BOOL finished = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
        if (finished && !result) {
            result = [UIImage fixOrientation:result];
//            result = [result resizeImageWithNewSize:[UIImage retriveScaleDstSize:result.size]];
            //回调
            completionBlock ? completionBlock(result, info) : nil;
        }
    }];
}

- (void)getOriginImageFromPHAsset:(PHAsset *)asset comletionBlock:(void (^)(UIImage *))completionBlock{
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.synchronous = NO;
    
    [self.cacheImageManager requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        result = [UIImage fixOrientation:result];
        //回调
        completionBlock ? completionBlock(result) : nil;
    }];
}

#pragma mark - Lazy Load
- (PHCachingImageManager *)cacheImageManager{
    if (_cacheImageManager == nil) {
        self.cacheImageManager = [[PHCachingImageManager alloc] init];
    }
    return _cacheImageManager;
}

@end
