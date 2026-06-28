package com.nhu.aisizheng.service;

import io.minio.*;
import io.minio.http.Method;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * MinIO 对象存储服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StorageService {

    private final MinioClient minioClient;

    @Value("${minio.bucket}")
    private String bucket;

    /**
     * 上传文件
     * @return 对象路径
     */
    public String upload(MultipartFile file, String folder) throws Exception {
        String objectName = folder + "/" + UUID.randomUUID() + "_" + file.getOriginalFilename();

        minioClient.putObject(
                PutObjectArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .stream(file.getInputStream(), file.getSize(), -1)
                        .contentType(file.getContentType())
                        .build()
        );

        log.info("文件上传成功: {}", objectName);
        return objectName;
    }

    /**
     * 上传字节数组（用于人脸图片等BASE64解码后的数据）
     */
    public String upload(byte[] data, String folder, String filename, String contentType) throws Exception {
        String objectName = folder + "/" + UUID.randomUUID() + "_" + filename;

        minioClient.putObject(
                PutObjectArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .stream(new java.io.ByteArrayInputStream(data), data.length, -1)
                        .contentType(contentType)
                        .build()
        );

        log.info("文件上传成功: {}", objectName);
        return objectName;
    }

    /**
     * 生成预签名URL（有效期7天）
     */
    public String getPresignedUrl(String objectName) throws Exception {
        return minioClient.getPresignedObjectUrl(
                GetPresignedObjectUrlArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .method(Method.GET)
                        .expiry(7, TimeUnit.DAYS)
                        .build()
        );
    }

    /**
     * 删除对象
     */
    public void delete(String objectName) throws Exception {
        minioClient.removeObject(
                RemoveObjectArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .build()
        );
    }

    /**
     * 检查Bucket是否存在，不存在则创建
     */
    public void ensureBucket() throws Exception {
        boolean exists = minioClient.bucketExists(
                BucketExistsArgs.builder().bucket(bucket).build()
        );
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
            log.info("Bucket [{}] 已创建", bucket);
        }
    }
}
