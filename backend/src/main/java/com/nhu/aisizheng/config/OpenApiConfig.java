package com.nhu.aisizheng.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    private static final String BEARER_AUTH = "bearerAuth";

    @Bean
    public OpenAPI aiSizhengOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("AI思政辅助APP API")
                        .version("1.1.0")
                        .description("南华大学计算机学院 AI思政打卡、教师管理、消息、定位、人脸与审计接口文档。")
                        .contact(new Contact()
                                .name("计算机学院 AI思政项目组"))
                        .license(new License()
                                .name("Internal Pilot")))
                .servers(List.of(
                        new Server().url("http://localhost:8080").description("本地开发"),
                        new Server().url("http://127.0.0.1:8080").description("真机 ADB reverse / 本机调试")))
                .components(new Components().addSecuritySchemes(BEARER_AUTH,
                        new SecurityScheme()
                                .name(BEARER_AUTH)
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("登录接口返回的 accessToken，调用受保护接口时填入 Bearer Token。")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_AUTH));
    }
}
