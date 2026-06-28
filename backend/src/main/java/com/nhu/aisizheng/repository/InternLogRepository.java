package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.InternLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface InternLogRepository extends JpaRepository<InternLog, Long> {

    Optional<InternLog> findByUserIdAndWorkDate(Long userId, LocalDate workDate);

    List<InternLog> findByUserIdOrderByWorkDateDesc(Long userId);

    List<InternLog> findByWorkDate(LocalDate workDate);

    List<InternLog> findAllByOrderByWorkDateDesc();
}
