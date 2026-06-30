package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByStudentId(String studentId);

    boolean existsByStudentId(String studentId);

    Optional<User> findByStudentIdAndStatus(String studentId, String status);

    List<User> findByRoleAndStatus(String role, String status);

    List<User> findByClassIdAndRoleAndStatus(Long classId, String role, String status);

    List<User> findByRole(String role);

    List<User> findByClassIdAndRole(Long classId, String role);
}
