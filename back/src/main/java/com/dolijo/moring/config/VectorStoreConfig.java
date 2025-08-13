package com.dolijo.moring.config;

import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.ai.vectorstore.redis.RedisVectorStore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import redis.clients.jedis.DefaultJedisClientConfig;
import redis.clients.jedis.HostAndPort;
import redis.clients.jedis.JedisPooled;

@Configuration
public class VectorStoreConfig {

    @Value("${spring.ai.vectorstore.redis.index}")
    private String index;

    @Value("${spring.ai.vectorstore.redis.prefix}")
    private String prefix;

    @Value("${spring.data.redis.host}")
    private String redisHost;

    @Value("${spring.data.redis.port}")
    private int redisPort;

    @Value("${spring.data.redis.password:}") // 비어 있을 수 있음
    private String redisPassword;

    @Bean(destroyMethod = "close")
    public JedisPooled jedisPooled(
            @Value("${spring.data.redis.host:localhost}") String host,
            @Value("${spring.data.redis.port:6379}") int port,
            @Value("${spring.data.redis.password:}") String password
    ) {
        return (password == null || password.isBlank())
                ? new JedisPooled(host, port)
                : new JedisPooled(new HostAndPort(host, port),
                DefaultJedisClientConfig.builder().password(password).build());
    }

    @Bean(name = "moringVectorStore")
    @Primary
    public VectorStore moringVectorStore(
            JedisPooled jedis,
            EmbeddingModel embeddingModel,
            @Value("${spring.ai.vectorstore.redis.index}") String index,
            @Value("${spring.ai.vectorstore.redis.prefix}") String prefix
    ) {
        return RedisVectorStore.builder(jedis, embeddingModel)
                .indexName(index)
                .prefix(prefix)
                .metadataFields(
                        RedisVectorStore.MetadataField.tag("category"),
                        RedisVectorStore.MetadataField.text("source"),
                        RedisVectorStore.MetadataField.tag("collection"),
                        RedisVectorStore.MetadataField.text("lang")
                )
                .initializeSchema(true)
                .build();
    }
}
